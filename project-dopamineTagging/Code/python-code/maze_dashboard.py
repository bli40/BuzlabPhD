"""
Radial Arm Maze — Live Serial Monitor Dashboard
================================================
Layout (2 × 3):
  [0,0]  Top-down maze diagram  — green circle = rewarded arm this trial,
                                   red dot = unrewarded poke this trial,
                                   trial number in hub centre
  [0,1]  Unique poke count per arm per trial (line plot, 1 line / arm)
           "Unique" = first poke on an arm before the *next* poke on a
           *different* arm (consecutive repeats while licking are collapsed)
  [0,2]  Time-to-first-reward per arm across trials (scatter + line)
  [1,0]  Cumulative rewards over time
  [1,1]  Inter-poke interval per poke event
  [1,2]  Arm preference heatmap (total unique pokes per arm)

Usage
-----
  Live serial:
    python maze_dashboard.py --port COM3 --baud 9600

  Replay a saved log file:
    python maze_dashboard.py --log path/to/serial_log.txt

  Built-in demo data:
    python maze_dashboard.py --demo
"""

import argparse
import math
import re
import threading
import time
import collections
import sys

import matplotlib
import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
import matplotlib.gridspec as gridspec
import matplotlib.ticker
import numpy as np

# ── colour palette ─────────────────────────────────────────────────────────────
BG        = "#0d1117"
PANEL_BG  = "#161b22"
ACCENT    = "#58a6ff"
GREEN     = "#3fb950"
RED       = "#f85149"
YELLOW    = "#d29922"
MUTED     = "#8b949e"
WHITE     = "#e6edf3"
ARM_COLOR = "#30363d"

# 8 visually distinct colours for per-arm lines
ARM_PALETTE = [
    "#58a6ff", "#3fb950", "#f85149", "#d29922",
    "#bc8cff", "#ff7b72", "#79c0ff", "#56d364",
]

matplotlib.rcParams.update({
    "figure.facecolor":  BG,
    "axes.facecolor":    PANEL_BG,
    "axes.edgecolor":    ARM_COLOR,
    "axes.labelcolor":   WHITE,
    "xtick.color":       MUTED,
    "ytick.color":       MUTED,
    "text.color":        WHITE,
    "grid.color":        ARM_COLOR,
    "grid.linestyle":    "--",
    "grid.alpha":        0.5,
    "font.family":       "monospace",
})

# ── maze geometry ──────────────────────────────────────────────────────────────
N_ARMS     = 8          # <- change to match your physical maze
ARM_LENGTH = 1.0
ARM_ANGLES = [2 * math.pi * i / N_ARMS for i in range(N_ARMS)]  # arm 1 = index 0

def arm_tip(arm_id):
    idx   = (arm_id - 1) % N_ARMS
    angle = ARM_ANGLES[idx]
    return (ARM_LENGTH * math.cos(angle), ARM_LENGTH * math.sin(angle))

# ── shared state ───────────────────────────────────────────────────────────────
class MazeState:
    """
    Thread-safe store for parsed events.

    Per-event structure
    -------------------
    poke  : {arm, time_s, rewarded, wall_time, unique}
              unique=True  -> first poke on this arm in a non-consecutive run
              unique=False -> consecutive repeat (mouse still at same arm)

    trial : {trial, pokes, rewards, duration}
              pokes   = all raw poke events for that trial
              rewards = subset that were rewarded
    """
    def __init__(self):
        self.lock              = threading.Lock()
        self.trial             = 0
        self.all_pokes         = []   # every poke across all trials
        self.trials            = []   # completed trial dicts
        self._t_pokes          = []   # pokes in the current live trial
        self._t_rewards        = []   # rewards in the current live trial
        self._last_arm         = None # for consecutive-repeat detection
        self._trial_start_wall = None

    def start_trial(self, n):
        with self.lock:
            self.trial             = n
            self._t_pokes          = []
            self._t_rewards        = []
            self._last_arm         = None
            self._trial_start_wall = time.time()

    def add_poke(self, arm, time_s, wall_time):
        """
        Record a poke. unique=True only if this arm differs from the previous
        poke (consecutive repeats while licking are collapsed to unique=False).
        rewarded starts False; patch_reward() flips it.
        """
        unique = (arm != self._last_arm)
        ev = dict(arm=arm, time_s=time_s, rewarded=False,
                  wall_time=wall_time, unique=unique)
        with self.lock:
            self.all_pokes.append(ev)
            self._t_pokes.append(ev)
            self._last_arm = arm

    def patch_reward(self, arm):
        """Back-fill the most recent unrewarded poke on this arm."""
        with self.lock:
            for ev in reversed(self._t_pokes):
                if ev["arm"] == arm and not ev["rewarded"]:
                    ev["rewarded"] = True
                    self._t_rewards.append(ev)
                    break

    def end_trial(self, n):
        with self.lock:
            duration = (time.time() - self._trial_start_wall
                        if self._trial_start_wall else 0)
            self.trials.append(dict(
                trial    = n,
                pokes    = list(self._t_pokes),
                rewards  = list(self._t_rewards),
                duration = duration,
            ))

    def snapshot(self):
        with self.lock:
            return dict(
                trial     = self.trial,
                all_pokes = list(self.all_pokes),
                trials    = list(self.trials),
                t_pokes   = list(self._t_pokes),
                t_rewards = list(self._t_rewards),
            )

STATE = MazeState()

# ── regex patterns ─────────────────────────────────────────────────────────────
RE_TIMESTAMP   = re.compile(r"^[\d:\.]+\s+->\s+(.*)$")
RE_TRIAL_START = re.compile(r"###\s+Trial\s+(\d+)")
RE_TRIAL_END   = re.compile(r"Completed\s+Trial\s+(\d+)")
RE_POKE        = re.compile(r"(\d+)\s+poked\s+@\s+([\d.]+)s")
RE_REWARD      = re.compile(r"<<<(\d+)\s+rewarded>>>")

def parse_line(line: str):
    """Dispatch one text line to the appropriate STATE update."""
    line = line.strip()
    if not line:
        return
    m = RE_TIMESTAMP.match(line)
    content = m.group(1).strip() if m else line

    if (m := RE_TRIAL_START.search(content)):
        STATE.start_trial(int(m.group(1)))
        return
    if (m := RE_TRIAL_END.search(content)):
        STATE.end_trial(int(m.group(1)))
        return
    if (m := RE_POKE.search(content)):
        STATE.add_poke(arm=int(m.group(1)),
                       time_s=float(m.group(2)),
                       wall_time=time.time())
        return
    if (m := RE_REWARD.search(content)):
        STATE.patch_reward(arm=int(m.group(1)))
        return

# ── serial reader ──────────────────────────────────────────────────────────────
def serial_reader(port, baud):
    """
    Accumulates raw bytes from the serial port into a line buffer.
    Dispatches complete lines (terminated by \\n) to parse_line().
    Uses a short read timeout + small sleep when idle to avoid 100% CPU.
    """
    try:
        import serial
    except ImportError:
        print("pyserial not installed.  Run:  pip install pyserial", file=sys.stderr)
        sys.exit(1)

    print(f"[serial] opening {port} @ {baud} baud ...")
    with serial.Serial(port, baud, timeout=0.1) as ser:
        buf = b""
        while True:
            chunk = ser.read(64)          # read up to 64 bytes, returns immediately if timeout
            if chunk:
                buf += chunk
                while b"\n" in buf:
                    line_bytes, buf = buf.split(b"\n", 1)
                    try:
                        parse_line(line_bytes.decode("utf-8", errors="replace"))
                    except Exception as exc:
                        print(f"[parse error] {exc}", file=sys.stderr)
            else:
                time.sleep(0.005)         # brief idle sleep

# ── log-file reader ────────────────────────────────────────────────────────────
def log_reader(path, realtime=True):
    """
    Replay a saved serial log.  If realtime=True the wall-clock timestamps
    in the log are used to pace playback at the original session speed.
    """
    ts_re    = re.compile(r"^(\d{2}):(\d{2}):(\d{2})\.(\d+)\s+->")
    prev_ts  = None

    with open(path, "r", errors="replace") as fh:
        for line in fh:
            if realtime:
                m = ts_re.match(line)
                if m:
                    h, mi, s = int(m.group(1)), int(m.group(2)), int(m.group(3))
                    ts = h * 3600 + mi * 60 + s + float(f"0.{m.group(4)}")
                    if prev_ts is not None:
                        gap = ts - prev_ts
                        if 0 < gap < 10:
                            time.sleep(gap)
                    prev_ts = ts
            parse_line(line)
    print("[log] replay finished — dashboard stays live")

# ── built-in demo data ─────────────────────────────────────────────────────────
DEMO_LOG = """\
19:55:16.044 -> Completed Trial 1
19:55:21.027 -> ### Trial 2
19:55:32.515 -> 3 poked @ 11.52s
19:55:32.515 -> <<<3 rewarded>>>
19:55:37.168 -> 1 poked @ 16.20s
19:55:37.201 -> <<<1 rewarded>>>
19:55:39.646 -> 2 poked @ 18.69s
19:55:39.679 -> Completed Trial 2
19:55:44.683 -> ### Trial 3
19:56:24.000 -> 1 poked @ 39.41s
19:56:24.033 -> <<<1 rewarded>>>
19:56:24.164 -> 1 poked @ 39.57s
19:56:26.244 -> 3 poked @ 41.66s
19:56:26.277 -> <<<3 rewarded>>>
19:56:28.145 -> 2 poked @ 43.56s
19:56:28.177 -> Completed Trial 3
19:56:33.181 -> ### Trial 4
19:56:45.000 -> 5 poked @ 11.82s
19:56:45.033 -> <<<5 rewarded>>>
19:56:50.100 -> 7 poked @ 17.00s
19:56:55.200 -> 2 poked @ 22.10s
19:56:55.230 -> <<<2 rewarded>>>
19:56:58.300 -> 4 poked @ 25.20s
19:56:58.330 -> Completed Trial 4
""".splitlines()

def demo_reader():
    for line in DEMO_LOG:
        parse_line(line)
        time.sleep(0.12)

    import random
    rng       = random.Random(42)
    arms_rwd  = [1, 3, 5, 7]
    arms_all  = list(range(1, N_ARMS + 1))
    trial_num = 5

    while True:
        STATE.start_trial(trial_num)
        t    = 2.0
        prev = None
        for _ in range(rng.randint(4, 10)):
            arm = rng.choice(arms_all)
            # simulate occasional lick-repeat on same arm
            if rng.random() < 0.2 and prev is not None:
                arm = prev
            STATE.add_poke(arm, t, time.time())
            t += rng.uniform(0.5, 5.0)
            if arm in arms_rwd:
                STATE.patch_reward(arm)
            prev = arm
            time.sleep(0.30)
        STATE.end_trial(trial_num)
        trial_num += 1
        time.sleep(0.4)

# ── plot helpers ───────────────────────────────────────────────────────────────
def unique_pokes_by_arm(trials):
    """Returns {arm: [(trial_num, count), ...]} counting only unique pokes."""
    data = {a: [] for a in range(1, N_ARMS + 1)}
    for td in trials:
        counts = collections.Counter(
            ev["arm"] for ev in td["pokes"] if ev.get("unique", True)
        )
        for arm in range(1, N_ARMS + 1):
            data[arm].append((td["trial"], counts.get(arm, 0)))
    return data


def draw_maze(ax, snap):
    ax.clear()
    ax.set_aspect("equal")
    ax.set_xlim(-1.55, 1.55)
    ax.set_ylim(-1.55, 1.55)
    ax.axis("off")
    ax.set_facecolor(PANEL_BG)

    for angle in ARM_ANGLES:
        ax.plot([0, ARM_LENGTH * math.cos(angle)],
                [0, ARM_LENGTH * math.sin(angle)],
                color=ARM_COLOR, lw=6, solid_capstyle="round", zorder=1)

    ax.add_patch(plt.Circle((0, 0), 0.18, color="#21262d", zorder=3))
    ax.text(0, 0, f"T{snap['trial']}", ha="center", va="center",
            fontsize=13, fontweight="bold", color=ACCENT, zorder=4)

    for i in range(N_ARMS):
        ax.text(1.38 * math.cos(ARM_ANGLES[i]), 1.38 * math.sin(ARM_ANGLES[i]),
                str(i + 1), ha="center", va="center", fontsize=7, color=MUTED, zorder=2)

    for arm in {ev["arm"] for ev in snap["t_rewards"]}:
        tx, ty = arm_tip(arm)
        ax.add_patch(plt.Circle((tx, ty), 0.13, color=GREEN, alpha=0.85, zorder=5))

    for ev in snap["t_pokes"]:
        if not ev["rewarded"]:
            tx, ty = arm_tip(ev["arm"])
            ax.plot(tx, ty, "o", color=RED, ms=8, zorder=6, alpha=0.8)

    ax.legend(handles=[
        mpatches.Patch(color=GREEN, label="Rewarded"),
        mpatches.Patch(color=RED,   label="Unrewarded poke"),
    ], loc="lower right", fontsize=6, framealpha=0.3, facecolor=PANEL_BG, edgecolor=ARM_COLOR)
    ax.set_title("Maze View", color=ACCENT, fontsize=9, pad=4)


def draw_unique_pokes_per_arm(ax, snap):
    """Line plot: unique poke count per arm across trials (1 line / arm)."""
    ax.clear()
    trials = snap["trials"]
    if not trials:
        ax.text(0.5, 0.5, "Awaiting data...", transform=ax.transAxes,
                ha="center", va="center", color=MUTED)
        ax.set_title("Unique Pokes per Arm per Trial", color=ACCENT, fontsize=9)
        return

    data = unique_pokes_by_arm(trials)
    any_plotted = False
    for arm in range(1, N_ARMS + 1):
        pts = data[arm]
        xs  = [p[0] for p in pts]
        ys  = [p[1] for p in pts]
        if not any(y > 0 for y in ys):
            continue
        color = ARM_PALETTE[(arm - 1) % len(ARM_PALETTE)]
        ax.plot(xs, ys, "-o", color=color, ms=4, lw=1.5, label=f"Arm {arm}")
        any_plotted = True

    if any_plotted:
        ax.legend(fontsize=6, framealpha=0.3, facecolor=PANEL_BG,
                  edgecolor=ARM_COLOR, ncol=2)
    ax.set_xlabel("Trial", fontsize=7)
    ax.set_ylabel("Unique pokes", fontsize=7)
    ax.set_title("Unique Pokes per Arm per Trial", color=ACCENT, fontsize=9)
    ax.xaxis.set_major_locator(matplotlib.ticker.MaxNLocator(integer=True))
    ax.tick_params(labelsize=7)
    ax.grid()


def draw_time_to_reward_by_arm(ax, snap):
    """Scatter+line: time to first reward per arm per trial (1 line / arm)."""
    ax.clear()
    trials = snap["trials"]
    if not trials:
        ax.text(0.5, 0.5, "Awaiting data...", transform=ax.transAxes,
                ha="center", va="center", color=MUTED)
        ax.set_title("Time to First Reward by Arm", color=ACCENT, fontsize=9)
        return

    arm_data = collections.defaultdict(list)
    for td in trials:
        seen = set()
        for ev in td["rewards"]:
            arm = ev["arm"]
            if arm not in seen:
                arm_data[arm].append((td["trial"], ev["time_s"]))
                seen.add(arm)

    any_plotted = False
    for arm, pts in sorted(arm_data.items()):
        color = ARM_PALETTE[(arm - 1) % len(ARM_PALETTE)]
        xs = [p[0] for p in pts]
        ys = [p[1] for p in pts]
        ax.plot(xs, ys, "-o", color=color, ms=5, lw=1.5, label=f"Arm {arm}")
        any_plotted = True

    if any_plotted:
        ax.legend(fontsize=6, framealpha=0.3, facecolor=PANEL_BG,
                  edgecolor=ARM_COLOR, ncol=2)
    ax.set_xlabel("Trial", fontsize=7)
    ax.set_ylabel("Time to first reward (s)", fontsize=7)
    ax.set_title("Time to First Reward by Arm", color=ACCENT, fontsize=9)
    ax.xaxis.set_major_locator(matplotlib.ticker.MaxNLocator(integer=True))
    ax.tick_params(labelsize=7)
    ax.grid()


def draw_cumulative_rewards(ax, snap):
    ax.clear()
    pokes = snap["all_pokes"]
    if not pokes:
        ax.text(0.5, 0.5, "Awaiting data...", transform=ax.transAxes,
                ha="center", va="center", color=MUTED)
        ax.set_title("Cumulative Rewards", color=ACCENT, fontsize=9)
        return

    t0      = pokes[0]["wall_time"]
    elapsed = [p["wall_time"] - t0 for p in pokes]
    cumrew  = np.cumsum([1 if p["rewarded"] else 0 for p in pokes])
    cumpoke = np.arange(1, len(pokes) + 1)

    ax.step(elapsed, cumrew,  where="post", color=GREEN,  lw=2,   label="Rewards")
    ax.step(elapsed, cumpoke, where="post", color=ACCENT, lw=1.2, alpha=0.6, label="All pokes")
    ax.set_xlabel("Session elapsed (s)", fontsize=7)
    ax.set_ylabel("Count", fontsize=7)
    ax.set_title("Cumulative Rewards", color=ACCENT, fontsize=9)
    ax.legend(fontsize=6, framealpha=0.3, facecolor=PANEL_BG, edgecolor=ARM_COLOR)
    ax.tick_params(labelsize=7)
    ax.grid()


def draw_ipi(ax, snap):
    ax.clear()
    pokes = snap["all_pokes"]
    if len(pokes) < 2:
        ax.text(0.5, 0.5, "Awaiting data...", transform=ax.transAxes,
                ha="center", va="center", color=MUTED)
        ax.set_title("Inter-Poke Interval", color=ACCENT, fontsize=9)
        return

    times = [p["wall_time"] for p in pokes]
    ipis  = [times[i + 1] - times[i] for i in range(len(times) - 1)]
    cols  = [GREEN if pokes[i + 1]["rewarded"] else YELLOW for i in range(len(ipis))]

    ax.bar(range(len(ipis)), ipis, color=cols, edgecolor=BG, width=0.7)
    ax.set_xlabel("Poke index", fontsize=7)
    ax.set_ylabel("IPI (s)", fontsize=7)
    ax.set_title("Inter-Poke Interval", color=ACCENT, fontsize=9)
    ax.tick_params(labelsize=7)
    ax.grid(axis="y")
    ax.legend(handles=[
        mpatches.Patch(color=GREEN,  label="-> rewarded"),
        mpatches.Patch(color=YELLOW, label="-> unrewarded"),
    ], fontsize=6, framealpha=0.3, facecolor=PANEL_BG, edgecolor=ARM_COLOR)


def draw_arm_heatmap(ax, snap):
    ax.clear()
    counts = collections.Counter(
        p["arm"] for p in snap["all_pokes"] if p.get("unique", True)
    )
    arms   = list(range(1, N_ARMS + 1))
    vals   = [counts.get(a, 0) for a in arms]
    cmap   = matplotlib.colors.LinearSegmentedColormap.from_list(
        "maze", [PANEL_BG, ACCENT, GREEN])
    norm   = matplotlib.colors.Normalize(vmin=0, vmax=max(vals) or 1)
    ax.bar([str(a) for a in arms], vals,
           color=[cmap(norm(v)) for v in vals], edgecolor=BG, width=0.7)
    ax.set_xlabel("Arm", fontsize=7)
    ax.set_ylabel("Unique pokes (total)", fontsize=7)
    ax.set_title("Arm Preference (unique pokes)", color=ACCENT, fontsize=9)
    ax.tick_params(labelsize=7)
    ax.grid(axis="y")
    sm = plt.cm.ScalarMappable(cmap=cmap, norm=norm)
    sm.set_array([])
    plt.colorbar(sm, ax=ax, pad=0.02, fraction=0.04).ax.tick_params(labelsize=6)


# ── main ───────────────────────────────────────────────────────────────────────
def main():
    parser = argparse.ArgumentParser(description="Radial Arm Maze Dashboard")
    grp = parser.add_mutually_exclusive_group()
    grp.add_argument("--port", help="Serial port (e.g. COM3, /dev/ttyUSB0)")
    grp.add_argument("--log",  help="Path to saved serial log file")
    grp.add_argument("--demo", action="store_true", help="Run built-in demo")
    parser.add_argument("--baud", default=9600, type=int)
    parser.add_argument("--fps",  default=4,    type=float)
    args = parser.parse_args()

    if not args.port and not args.log and not args.demo:
        print("No source given — defaulting to --demo")
        args.demo = True

    if args.demo:
        reader = threading.Thread(target=demo_reader, daemon=True)
    elif args.log:
        reader = threading.Thread(target=log_reader, args=(args.log,), daemon=True)
    else:
        reader = threading.Thread(target=serial_reader, args=(args.port, args.baud), daemon=True)
    reader.start()

    fig = plt.figure(figsize=(18, 10))
    fig.patch.set_facecolor(BG)
    fig.suptitle("Radial Arm Maze — Live Dashboard",
                 color=ACCENT, fontsize=14, fontweight="bold", y=0.98)
    gs   = gridspec.GridSpec(2, 3, figure=fig,
                             hspace=0.40, wspace=0.34,
                             left=0.06, right=0.97, top=0.93, bottom=0.07)
    axes = [fig.add_subplot(gs[r, c]) for r in range(2) for c in range(3)]

    try:
        plt.get_current_fig_manager().window.showMaximized()
    except Exception:
        pass

    def update(_=None):
        snap = STATE.snapshot()
        draw_maze(axes[0], snap)
        draw_unique_pokes_per_arm(axes[1], snap)
        draw_time_to_reward_by_arm(axes[2], snap)
        draw_cumulative_rewards(axes[3], snap)
        draw_ipi(axes[4], snap)
        draw_arm_heatmap(axes[5], snap)
        fig.canvas.draw_idle()

    timer = fig.canvas.new_timer(interval=int(1000 / args.fps))
    timer.add_callback(update)
    timer.start()
    update()
    plt.show()


if __name__ == "__main__":
    main()