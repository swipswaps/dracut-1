#!/bin/bash
# -*- mode: shell-script; indent-tabs-mode: nil; sh-basic-offset: 4; -*-
# ex: ts=8 sw=4 sts=4 et filetype=sh

# called by dracut
check() {
    return 0
}

# called by dracut
depends() {
    echo fs-lib
}

cmdline_journal() {
    if [[ $hostonly ]]; then
        for dev in "${!host_fs_types[@]}"; do
            [[ ${host_fs_types[$dev]} = "reiserfs" ]] || [[ ${host_fs_types[$dev]} = "xfs" ]] || continue
            rootopts=$(find_dev_fsopts "$dev")
            if [[ ${host_fs_types[$dev]} = "reiserfs" ]]; then
                journaldev=$(fs_get_option $rootopts "jdev")
            elif [[ ${host_fs_types[$dev]} = "xfs" ]]; then
                journaldev=$(fs_get_option $rootopts "logdev")
            fi

            if [ -n "$journaldev" ]; then
                echo "root.journaldev=${journaldev}"
            fi
        done
    fi
    return 0
}

cmdline_rootfs() {
    local dev=/dev/block/$(find_root_block_device)
    if [ -e $dev ]; then
        printf "root=%s rootflags=%s rootfstype=%s\n" \
            "$(shorten_persistent_dev "$(get_persistent_dev "$dev")")" \
            "$(find_mp_fsopts /)" "$(find_mp_fstype /)"
    fi
}

# called by dracut
cmdline() {
    cmdline_rootfs
    cmdline_journal
}

# called by dracut
install() {
    if [[ $hostonly_cmdline == "yes" ]]; then
        local _journaldev=$(cmdline_journal)
        [[ $_journaldev ]] && printf "%s\n" "$_journaldev" >> "${initdir}/etc/cmdline.d/95root-journaldev.conf"
        local _rootdev=$(cmdline_rootfs)
        [[ $_rootdev ]] && printf "%s\n" "$_rootdev" >> "${initdir}/etc/cmdline.d/95root-dev.conf"
    fi

    inst_multiple umount
    inst_multiple tr
    if ! dracut_module_included "systemd"; then
        inst_hook cmdline 95 "$moddir/parse-block.sh"
        inst_hook pre-udev 30 "$moddir/block-genrules.sh"
        inst_hook mount 99 "$moddir/mount-root.sh"
    fi

    inst_hook initqueue/timeout 99 "$moddir/rootfallback.sh"
}
