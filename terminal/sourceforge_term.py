#!/usr/bin/env python3
# SourceForge 2.0 Custom Terminal (keyboard-only)
# Top banner + middle framed PTY window + bottom control bar

import curses, os, pty, fcntl, termios, struct, sys, select, tty
try:
    import pyte
except ImportError:
    pyte = None

BG   = (20, 40, 60)
TOP  = (35, 45, 60)
MID  = (28, 70, 120)
PINK = (255, 105, 180)
SHAD = (60, 60, 90)

TOP_HEIGHT = int(os.environ.get("TOP_HEIGHT", "6"))
MID_HEIGHT = int(os.environ.get("MID_HEIGHT", "12"))
INSET_L, INSET_R = 2, 2

CHILD_CMD = os.environ.get("SHELL_CMD", os.path.join(os.path.dirname(__file__), "..", "shell", "run.sh"))
if not os.path.isfile(CHILD_CMD):
    CHILD_CMD = os.environ.get("SHELL_CMD", "/bin/bash")

def esc_bg(r,g,b): return f"\x1b[48;2;{r};{g};{b}m"
def esc_fg(r,g,b): return f"\x1b[38;2;{r};{g};{b}m"
def esc_reset():   return "\x1b[0m"

def fill_row(stdscr, row, cols, rgb):
    stdscr.addstr(row, 0, esc_bg(*rgb) + " " * cols + esc_reset())

def frame(stdscr, y,x,h,w,rgb):
    stdscr.addstr(y, x,     esc_fg(*rgb) + "┌" + "─"*(w-2) + "┐" + esc_reset())
    for r in range(y+1, y+h-1):
        stdscr.addstr(r, x,         esc_fg(*rgb) + "│" + esc_reset())
        stdscr.addstr(r, x+w-1,     esc_fg(*rgb) + "│" + esc_reset())
    stdscr.addstr(y+h-1, x, esc_fg(*rgb) + "└" + "─"*(w-2) + "┘" + esc_reset())

def pixel_shadow(stdscr, y,x,h,w,rgb):
    if h > 0 and w > 0:
        if y+h < curses.LINES:
            stdscr.addstr(y+h,   x+1, esc_fg(*rgb) + "▀"*(max(0,w-2)) + esc_reset())
        for r in range(y+1, min(y+h, curses.LINES)):
            if x+w < curses.COLS:
                stdscr.addstr(r, x+w, esc_fg(*rgb) + "▒" + esc_reset())

def set_winsize(fd, rows, cols):
    fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack("HHHH", rows, cols, 0, 0))

def draw_controls(stdscr, rows, cols):
    bar1 = " ESC  /  -   CTRL   ALT  PGUP"
    bar2 = " HOME  END    ▲   ◀   ▼   ▶   PGDN"
    stdscr.addstr(rows-2, 0, esc_bg(0,0,0) + esc_fg(245,245,245) + bar1.ljust(cols) + esc_reset())
    stdscr.addstr(rows-1, 0, esc_bg(0,0,0) + esc_fg(245,245,245) + bar2.ljust(cols) + esc_reset())

def paint_chrome(stdscr):
    stdscr.erase()
    rows, cols = stdscr.getmaxyx()
    for r in range(min(TOP_HEIGHT, rows)):
        fill_row(stdscr, r, cols, TOP)
    for i in range(MID_HEIGHT):
        rr = TOP_HEIGHT + i
        if rr >= rows: break
        fill_row(stdscr, rr, cols, MID)
    for r in range(TOP_HEIGHT + MID_HEIGHT, rows):
        fill_row(stdscr, r, cols, BG)
    y = TOP_HEIGHT; x = INSET_L; h = max(3, min(MID_HEIGHT, rows - TOP_HEIGHT - 2)); w = max(6, cols - (INSET_L+INSET_R))
    if h>=3 and w>=6:
        frame(stdscr, y, x, h, w, PINK)
        if y+h < rows-2 and x+w < cols:
            pixel_shadow(stdscr, y, x, h, w, SHAD)
    draw_controls(stdscr, rows, cols)
    stdscr.refresh()
    return y, x, h, w

def run(stdscr):
    curses.curs_set(1)
    stdscr.keypad(True)
    stdscr.nodelay(True)
    y,x,h,w = paint_chrome(stdscr)
    view_y, view_x = y+1, x+1
    view_h, view_w = h-2, w-2
    if view_h < 2 or view_w < 10:
        stdscr.addstr(0,0,"Too small"); stdscr.refresh(); stdscr.getch(); return
    pid, master = pty.fork()
    if pid==0: os.execv(CHILD_CMD,[os.path.basename(CHILD_CMD)])
    tty.setcbreak(sys.stdin.fileno())
    set_winsize(master, view_h, view_w)
    if pyte:
        screen=pyte.Screen(view_w,view_h); stream=pyte.ByteStream(screen)
    else: screen=None
    fl=fcntl.fcntl(master, fcntl.F_GETFL); fcntl.fcntl(master, fcntl.F_SETFL, fl|os.O_NONBLOCK)
    last_size=stdscr.getmaxyx()
    while True:
        r,c=stdscr.getmaxyx()
        if (r,c)!=last_size:
            y,x,h,w=paint_chrome(stdscr)
            view_y,view_x=y+1,x+1; view_h,view_w=h-2,w-2
            set_winsize(master,max(2,view_h),max(10,view_w))
            if pyte: screen.resize(view_w,view_h)
            last_size=(r,c)
        rlist,_,_=select.select([master],[],[],0.02)
        if master in rlist:
            try: data=os.read(master,8192)
            except OSError: break
            if not data: break
            if pyte:
                stream.feed(data.decode("utf-8","ignore"))
                for row_idx in range(view_h):
                    line=screen.display[row_idx]
                    if len(line)<view_w: line+=" "*(view_w-len(line))
                    else: line=line[:view_w]
                    stdscr.addstr(view_y+row_idx,view_x,line)
                stdscr.move(view_y+min(screen.cursor.y,view_h-1),view_x+min(screen.cursor.x,view_w-1))
                stdscr.refresh()
        try: ch=stdscr.get_wch()
        except curses.error: ch=None
        if ch is not None:
            if ch==curses.KEY_RESIZE: continue
            elif ch==curses.KEY_BACKSPACE or ch==127: os.write(master,b'\x7f')
            elif ch==3: os.write(master,b'\x03')
            elif ch==4: os.write(master,b'\x04')
            elif ch==curses.KEY_UP: os.write(master,b'\x1b[A')
            elif ch==curses.KEY_DOWN: os.write(master,b'\x1b[B')
            elif ch==curses.KEY_LEFT: os.write(master,b'\x1b[D')
            elif ch==curses.KEY_RIGHT: os.write(master,b'\x1b[C')
            elif isinstance(ch,str): os.write(master,ch.encode())
        try: done_pid,_=os.waitpid(pid,os.WNOHANG)
        except ChildProcessError: break
        if done_pid==pid: break
    stdscr.addstr(0,0,esc_reset()); stdscr.refresh()

if __name__=="__main__": curses.wrapper(run)
