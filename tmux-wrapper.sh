#!/bin/sh
# tmux-wrapper.sh - Prevents accidental tmux server creation
# The ccc tool uses a dedicated socket at /tmp/ccc.sock

# If user runs plain 'tmux' without arguments, block it
if [ $# -eq 0 ]; then
    echo "Error: Direct tmux usage is disabled in ccc containers." >&2
    echo "The ccc tool manages tmux internally via /tmp/ccc.sock" >&2
    echo "" >&2
    echo "To interact with the claude session, use:" >&2
    echo "  ccc attach -n <container-name>  (from host)" >&2
    echo "  ccc exec -n <container-name>    (from host)" >&2
    exit 1
fi

# If user specifies -S with our socket, allow it (internal use)
case "$*" in
    *"-S /tmp/ccc.sock"*)
        exec /usr/bin/tmux.real "$@"
        ;;
    *"-S"*)
        # User trying to use a different socket - could be host tmux mount
        exec /usr/bin/tmux.real "$@"
        ;;
    *)
        echo "Error: Please specify a socket with -S" >&2
        echo "Internal ccc socket: -S /tmp/ccc.sock" >&2
        exit 1
        ;;
esac
