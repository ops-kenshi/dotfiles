// Reads the ctrl+tab popup's keys and prints one word per key: next, prev, enter or esc, and "up" once
// ctrl is let go. tmux only sees key presses, but macOS knows which modifiers are down; checking every
// 5ms notices the release well within one keystroke (~70ms apart at 170wpm). Exits after enter, esc or up.
#include <CoreGraphics/CoreGraphics.h>
#include <poll.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

#define POLL_MS 5
#define ESC_MS 30
#define CTRL_N 0x0e
#define CTRL_P 0x10
#define ESC 0x1b

static int ctrl_down(void)
{
    return (CGEventSourceFlagsState(kCGEventSourceStateCombinedSessionState) & kCGEventFlagMaskControl) != 0;
}

// 1 if a byte arrived within ms
static int get(int ms, unsigned char *c)
{
    struct pollfd p = { .fd = STDIN_FILENO, .events = POLLIN };
    return poll(&p, 1, ms) > 0 && read(STDIN_FILENO, c, 1) == 1;
}

static void say(const char *word)
{
    printf("%s\n", word);
    fflush(stdout);
}

// Every encoding tmux might use for these keys, without the leading ESC
static const char *escape_word(const char *seq)
{
    static const char *next[] = { "[9;5u", "[27;5;9~", "[110;5u", "[27;5;110~" };
    static const char *prev[] = { "[Z", "[9;6u", "[27;6;9~", "[112;5u", "[27;5;112~" };
    for (size_t i = 0; i < sizeof next / sizeof *next; i++)
        if (!strcmp(seq, next[i]))
            return "next";
    for (size_t i = 0; i < sizeof prev / sizeof *prev; i++)
        if (!strcmp(seq, prev[i]))
            return "prev";
    return NULL;
}

int main(void)
{
    unsigned char c;
    for (;;) {
        if (!ctrl_down()) {
            say("up");
            return 0;
        }
        if (!get(POLL_MS, &c))
            continue;

        if (c == '\t' || c == CTRL_N) {
            say("next");
        } else if (c == CTRL_P) {
            say("prev");
        } else if (c == '\r') {
            say("enter");
            return 0;
        } else if (c == ESC) {
            // The rest of a sequence arrives at once; nothing straight after means a lone Esc
            char seq[16];
            size_t len = 0;
            while (len < sizeof seq - 1 && get(ESC_MS, &c)) {
                seq[len++] = c;
                if (len > 1 && c >= 0x40 && c <= 0x7e)
                    break;
            }
            seq[len] = '\0';
            if (!len) {
                say("esc");
                return 0;
            }
            const char *word = escape_word(seq);
            if (word)
                say(word);
        }
    }
}
