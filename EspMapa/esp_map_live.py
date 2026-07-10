import re
import sys
import queue
import threading
import argparse

import numpy as np
import matplotlib
import matplotlib.pyplot as plt
import matplotlib.animation as animation
from matplotlib.patches import Rectangle

GRID_SIZE = 5
ZONE_LETTERS = [chr(ord('A') + i) for i in range(GRID_SIZE * GRID_SIZE)]  

NODE_NAMES = ['A', 'E', 'U', 'Y', 'M']

VALID_RSSI_MIN = -100
VALID_RSSI_MAX = -1

MATRIX_HEADER_RE = re.compile(r"---\s*MATRIZ DE SINAIS \(RSSI\)\s*---")


def zone_to_grid(letter):
    """Retorna (col, row) da zona, row=0 é a linha de cima."""
    idx = ZONE_LETTERS.index(letter)
    row = idx // GRID_SIZE
    col = idx % GRID_SIZE
    return col, row


NODE_GRID_POS = {name: zone_to_grid(name) for name in NODE_NAMES}

def parse_matrices(path):
    """Varre um arquivo de log e retorna uma lista de dicts:
    {'row_labels': [...], 'col_labels': [...], 'data': np.ndarray}
    um item para cada bloco 'MATRIZ DE SINAIS (RSSI)' encontrado."""
    with open(path, 'r', encoding='utf-8', errors='ignore') as f:
        lines = f.readlines()

    matrices = []
    i, n = 0, len(lines)
    while i < n:
        if MATRIX_HEADER_RE.search(lines[i]):
            try:
                col_labels = lines[i + 1].split()
                k = len(col_labels)
                data = np.full((k, k), np.nan)
                row_labels = []
                for r in range(k):
                    row_line = lines[i + 2 + r]
                    row_label = row_line.strip().split(None, 1)[0]
                    row_labels.append(row_label)
                    values = re.findall(r'\[\s*(-?\d+)\s*\]', row_line)
                    values = [int(v) for v in values]
                    for c, v in enumerate(values[:k]):
                        data[r, c] = v
                matrices.append({
                    'row_labels': row_labels,
                    'col_labels': col_labels,
                    'data': data,
                })
                i += 2 + k
            except (IndexError, ValueError):
                i += 1  
        else:
            i += 1
    return matrices
class LiveMatrixParser:
    """Consome uma linha por vez (como chegam da serial) e devolve um dict
    de matriz completa sempre que um bloco 'MATRIZ DE SINAIS (RSSI)' termina
    de ser recebido."""

    def __init__(self):
        self.state = 'WAIT_HEADER'
        self.col_labels = None
        self.expected_rows = None
        self.rows_collected = []

    def feed_line(self, line):
        if self.state == 'WAIT_HEADER':
            if MATRIX_HEADER_RE.search(line):
                self.state = 'WAIT_COLS'
            return None

        if self.state == 'WAIT_COLS':
            cols = line.split()
            if not cols:
                return None
            self.col_labels = cols
            self.expected_rows = len(cols)
            self.rows_collected = []
            self.state = 'WAIT_ROWS'
            return None

        if self.state == 'WAIT_ROWS':
            tokens = line.strip().split(None, 1)
            if not tokens:
                return None
            row_label = tokens[0]
            values = re.findall(r'\[\s*(-?\d+)\s*\]', line)
            values = [int(v) for v in values]
            if len(values) < self.expected_rows:
                self.state = 'WAIT_HEADER'  
                return None
            self.rows_collected.append((row_label, values[:self.expected_rows]))
            if len(self.rows_collected) == self.expected_rows:
                row_labels = [r for r, _ in self.rows_collected]
                data = np.array([v for _, v in self.rows_collected], dtype=float)
                entry = {'row_labels': row_labels, 'col_labels': self.col_labels, 'data': data}
                self.state = 'WAIT_HEADER'
                return entry
            return None

        return None


def clean_matrix(entry):
    """Substitui valores impossíveis (overflow do firmware, 0 = 'sem leitura'
    e a diagonal principal) por NaN."""
    data = entry['data'].copy()
    k = data.shape[0]
    for r in range(k):
        for c in range(k):
            if r == c:
                data[r, c] = np.nan
                continue
            v = data[r, c]
            if v == 0 or v < VALID_RSSI_MIN or v > VALID_RSSI_MAX:
                data[r, c] = np.nan
    return data

def draw_zone_grid(ax):
    for idx, letter in enumerate(ZONE_LETTERS):
        col = idx % GRID_SIZE
        row = idx // GRID_SIZE
        y = GRID_SIZE - 1 - row
        rect = Rectangle((col, y), 0.92, 0.92, linewidth=1.2,
                          edgecolor='#9e9e9e', facecolor='#f5f5f5',
                          linestyle='--', alpha=0.6)
        ax.add_patch(rect)
        ax.text(col + 0.46, y + 0.8, letter, ha='center', va='center',
                fontsize=11, fontweight='bold', color='#616161')


def rssi_to_style(rssi):
    """Converte um valor de RSSI (dBm, ex.: -30 a -90) em (largura, cor, alpha)."""
    if np.isnan(rssi):
        return None
    r = max(min(rssi, -20), -90)
    strength = (r - (-90)) / ((-20) - (-90))  
    lw = 0.8 + strength * 4.5
    color = matplotlib.colormaps['RdYlGn'](strength)
    alpha = 0.45 + strength * 0.55
    return lw, color, alpha


def draw_links(ax, entry, matrix):
    labels = entry['row_labels']
    k = len(labels)
    drawn = set()
    for r in range(k):
        for c in range(k):
            if r == c:
                continue
            n1, n2 = labels[r], labels[c]
            if n1 not in NODE_GRID_POS or n2 not in NODE_GRID_POS:
                continue
            pair = tuple(sorted((n1, n2)))
            if pair in drawn:
                continue

            val, other = matrix[r, c], matrix[c, r]
            vals = [v for v in (val, other) if not np.isnan(v)]
            if not vals:
                continue
            avg = float(np.mean(vals))
            drawn.add(pair)

            style = rssi_to_style(avg)
            if style is None:
                continue
            lw, color, alpha = style

            x1, r1 = NODE_GRID_POS[n1]
            x2, r2 = NODE_GRID_POS[n2]
            y1, y2 = GRID_SIZE - 1 - r1, GRID_SIZE - 1 - r2

            ax.plot([x1 + 0.46, x2 + 0.46], [y1 + 0.46, y2 + 0.46],
                    color=color, linewidth=lw, alpha=alpha, zorder=2,
                    solid_capstyle='round')
            mx, my = (x1 + x2) / 2 + 0.46, (y1 + y2) / 2 + 0.46
            ax.text(mx, my, f"{avg:.0f} dBm", fontsize=8, color='#333',
                    ha='center', va='center',
                    bbox=dict(boxstyle='round,pad=0.15', fc='white',
                              ec='none', alpha=0.8),
                    zorder=3)


def draw_nodes(ax):
    for name, (col, row) in NODE_GRID_POS.items():
        y = GRID_SIZE - 1 - row
        ax.scatter(col + 0.46, y + 0.46, s=600, color='#1565c0', zorder=4,
                   edgecolor='white', linewidth=2)
        ax.text(col + 0.46, y + 0.46, name, color='white', fontsize=13,
                fontweight='bold', ha='center', va='center', zorder=5)


def plot_snapshot(entry, title="", save_path=None, ax=None, show=True):
    matrix = clean_matrix(entry)
    standalone = ax is None
    if standalone:
        fig, ax = plt.subplots(figsize=(8, 8))
    ax.clear()
    ax.set_xlim(-0.3, GRID_SIZE + 0.1)
    ax.set_ylim(-0.3, GRID_SIZE + 0.1)
    ax.set_aspect('equal')
    ax.axis('off')
    draw_zone_grid(ax)
    draw_links(ax, entry, matrix)
    draw_nodes(ax)
    ax.set_title(title, fontsize=13, fontweight='bold')
    if standalone:
        if save_path:
            plt.savefig(save_path, dpi=150, bbox_inches='tight')
            print(f"Mapa salvo em: {save_path}")
        if show:
            plt.show()
        plt.close(fig)
    return ax


def plot_average(matrices, save_path=None):
    cleaned = [clean_matrix(m) for m in matrices]
    labels = matrices[0]['row_labels']
    avg = np.nanmean(np.stack(cleaned, axis=0), axis=0)
    entry = {'row_labels': labels, 'col_labels': matrices[0]['col_labels'], 'data': avg}
    plot_snapshot(entry, title=f"Média de sinal RSSI ({len(matrices)} capturas)",
                  save_path=save_path)


def animate_matrices(matrices, save_path, interval_ms=400):
    fig, ax = plt.subplots(figsize=(8, 8))

    def update(i):
        plot_snapshot(matrices[i], title=f"Captura {i + 1}/{len(matrices)}",
                      ax=ax, show=False)

    anim = animation.FuncAnimation(fig, update, frames=len(matrices), interval=interval_ms)
    anim.save(save_path, writer='pillow', dpi=110)
    plt.close(fig)
    print(f"Animação salva em: {save_path}")


def serial_reader_thread(port, baud, line_queue, stop_event, log_path=None):
    import serial  # import tardio: só é necessário no modo ao vivo
    fh = open(log_path, 'a', encoding='utf-8') if log_path else None
    try:
        ser = serial.Serial(port, baud, timeout=1)
    except Exception as e:
        line_queue.put(('__ERROR__', str(e)))
        return
    try:
        while not stop_event.is_set():
            try:
                raw = ser.readline()
            except Exception as e:
                line_queue.put(('__ERROR__', str(e)))
                break
            if not raw:
                continue
            line = raw.decode('utf-8', errors='ignore')
            if fh:
                fh.write(line)
                fh.flush()
            line_queue.put(('LINE', line))
    finally:
        try:
            ser.close()
        except Exception:
            pass
        if fh:
            fh.close()


def list_ports():
    from serial.tools import list_ports as lp
    ports = list(lp.comports())
    if not ports:
        print("Nenhuma porta serial encontrada.")
        return
    print("Portas seriais disponíveis:")
    for p in ports:
        print(f"  {p.device}  -  {p.description}")


def run_live(port, baud, log_path=None, refresh_ms=300):
    line_queue = queue.Queue()
    stop_event = threading.Event()

    reader = threading.Thread(
        target=serial_reader_thread,
        args=(port, baud, line_queue, stop_event, log_path),
        daemon=True,
    )
    reader.start()

    parser = LiveMatrixParser()
    fig, ax = plt.subplots(figsize=(8, 8))
    state = {'entry': None, 'count': 0, 'error': None}

    ax.set_title("Aguardando dados da serial...", fontsize=13, fontweight='bold')
    ax.axis('off')

    def update(_frame):
        got_update = False
        while not line_queue.empty():
            kind, payload = line_queue.get()
            if kind == '__ERROR__':
                state['error'] = payload
                continue
            entry = parser.feed_line(payload)
            if entry:
                state['entry'] = entry
                state['count'] += 1
                got_update = True

        if state['error']:
            ax.clear()
            ax.axis('off')
            ax.text(0.5, 0.5, f"Erro na porta serial:\n{state['error']}",
                    ha='center', va='center', color='red', fontsize=11, wrap=True)
            return []

        if got_update and state['entry']:
            plot_snapshot(state['entry'],
                          title=f"Ao vivo — captura #{state['count']}",
                          ax=ax, show=False)
        return []

    ani = animation.FuncAnimation(fig, update, interval=refresh_ms, cache_frame_data=False)
    try:
        plt.show()
    finally:
        stop_event.set()
        reader.join(timeout=2)


def main():
    parser = argparse.ArgumentParser(
        description="Visualiza posições e RSSI dos nós ESP32 sobre o mapa de zonas "
                    "(ao vivo pela serial ou a partir de um arquivo de log).")

    modo = parser.add_mutually_exclusive_group()
    modo.add_argument('--port', help="Modo AO VIVO: porta serial (ex.: COM3, /dev/ttyUSB0)")
    modo.add_argument('--file', help="Modo ARQUIVO: caminho para um log já salvo (ex.: saida.txt)")

    # opções do modo ao vivo
    parser.add_argument('--baud', type=int, default=115200, help="Baud rate (padrão: 115200)")
    parser.add_argument('--log', metavar='ARQUIVO.txt',
                         help="[ao vivo] também salva tudo que chegar da serial nesse arquivo")
    parser.add_argument('--refresh-ms', type=int, default=300,
                         help="[ao vivo] intervalo de atualização do gráfico em ms (padrão: 300)")
    parser.add_argument('--list-ports', action='store_true',
                         help="Lista as portas seriais disponíveis e sai.")

    # opções do modo arquivo
    parser.add_argument('--index', type=int, default=None,
                         help="[arquivo] índice da captura a exibir (0-based). Padrão: última.")
    parser.add_argument('--avg', action='store_true',
                         help="[arquivo] mostra a média de todas as capturas válidas.")
    parser.add_argument('--animate', metavar='SAIDA.gif',
                         help="[arquivo] gera uma animação GIF com todas as capturas.")
    parser.add_argument('--save', metavar='SAIDA.png',
                         help="[arquivo] salva a figura estática em vez de abrir janela.")

    args = parser.parse_args()

    if args.list_ports:
        list_ports()
        return

    if args.port:
        run_live(args.port, args.baud, log_path=args.log, refresh_ms=args.refresh_ms)
        return

    if args.file:
        matrices = parse_matrices(args.file)
        if not matrices:
            print("Nenhuma matriz RSSI encontrada no arquivo.")
            return
        print(f"{len(matrices)} capturas de matriz RSSI encontradas.")

        if args.animate:
            animate_matrices(matrices, args.animate)
            return
        if args.avg:
            plot_average(matrices, save_path=args.save)
            return
        idx = args.index if args.index is not None else len(matrices) - 1
        idx = max(0, min(idx, len(matrices) - 1))
        plot_snapshot(matrices[idx], title=f"Captura {idx + 1}/{len(matrices)}",
                      save_path=args.save)
        return

    parser.print_help()
    print("\nUse --port (ao vivo) ou --file (arquivo de log). Use --list-ports para ver as portas seriais.")


if __name__ == '__main__':
    main()