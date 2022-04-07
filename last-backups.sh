# A script that can run on your local computer, to check the status of the various backups stored on the server, i.e. the last time they ran successfully.

function spinner() {
    local info="$1"
    local pid=$!
    local delay=0.1
    local spinstr='|/-\'
    while kill -0 $pid 2> /dev/null; do
        local temp=${spinstr#?}
        printf " [%c]  $info" "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        local reset="\b\b\b\b\b\b"
        for ((i=1; i<=$(echo $info | wc -c); i++)); do
            reset+="\b"
        done
        printf $reset
    done
    printf "    \b\b\b\b"
}

# usage:
(ssh borg@backup.local ls -al  status/) &
spinner ""

