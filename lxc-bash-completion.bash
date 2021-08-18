_lxc_containers_completion(){
    local cur
    local -a toks
    cur="${COMP_WORDS[COMP_CWORD]}"
    toks=( $(  lxc-ls | cut -d ' ' -f 1 | \grep "$cur" ))
    COMPREPLY=( "${toks[@]}" )
    return 0
}

_lxc_stopped_containers_completion(){
    local cur
    local -a toks
    cur="${COMP_WORDS[COMP_CWORD]}"
    toks=( $(  lxc-ls | grep STOPPED | cut -d ' ' -f 1 | \grep "$cur" ))
    COMPREPLY=( "${toks[@]}" )
    return 0
}

_lxc_running_containers_completion(){
    local cur
    local -a toks
    cur="${COMP_WORDS[COMP_CWORD]}"
    toks=( $(  lxc-ls | grep RUNNING | cut -d ' ' -f 1 | \grep "$cur" ))
    COMPREPLY=( "${toks[@]}" )
    return 0
}

_lxc_frozen_containers_completion(){
    local cur
    local -a toks
    cur="${COMP_WORDS[COMP_CWORD]}"
    toks=( $(  lxc-ls | grep FROZEN | cut -d ' ' -f 1 | \grep "$cur" ))
    COMPREPLY=( "${toks[@]}" )
    return 0
}

complete -F _lxc_running_containers_completion -o nospace lxc-stop
alias lxc-stop="sudo lxc-stop -n "

_lxc_shutdown(){
    local containerName=$1
    local containerInfo="$(_lxc_validate_containerName $containerName)"
    if [[ "" != "$(echo $containerInfo | grep STOPPED)" ]]
    then
        echo "container $containerName is already stopped"
        echo "$containerInfo"
        exit 1
    fi
    sudo lxc-attach -n $containerName -- poweroff
}
complete -F _lxc_running_containers_completion -o nospace lxc-shutdown
alias lxc-shutdown="_lxc_shutdown "

complete -F _lxc_containers_completion -o nospace lxc-info
alias lxc-info="sudo lxc-info -n "

complete -F _lxc_stopped_containers_completion -o nospace lxc-start
alias lxc-start="sudo lxc-start -n "

alias lxc-ls="sudo lxc-ls -f"

_lxc_get_ip(){
    local containerName=$1
    local result=$(sudo lxc-attach -n $containerName -- ip -4 -o route get 8.8.8.8 | sed 's#.*src \([^ ]*\).*#\1#')
    echo $result
}
complete -F _lxc_containers_completion -o nospace lxc-ip
alias lxc-ip="_lxc-get-ip"

_lxc_list_containers(){
      cd /var/lib/lxc;
      ls */ -d
      cd -;
  }

_lxc_validate_containerName(){
    local containerName=$1
    if [[ "" == "$containerName" ]]
    then
        echo "Please pass a container name.."
        _lxc_list_containers
        return 1
    fi
    local containerInfo=$(lxc-ls | \grep $containerName)
    if [[ "" == "$containerInfo" ]]
    then
        echo "Invalid container name: $containerName"
        _lxc_list_containers
        return 1
    fi
    echo $containerInfo
}

_lxc_offer_to_stop_container(){
    local c=$1
    echo ""
    echo "$c is running, stop this container?"
    select yn in "Yes" "No"; do
        case $yn in
            Yes ) echo "shutting down $c"; _lxc_shutdown $c; break;;
            No ) echo "leaving $c running"; break;;
        esac
    done
    echo ""
}

_lxc_list_running_containers_and_offer_to_stop(){
    local containerNameToExclude=$1
    local containerInfo="$(_lxc_validate_containerName $containerNameToExclude)"
    if [[ "" == "$containerInfo" ]]
    then
        exit 1
    fi
    for c in $(lxc-ls | grep RUNNING | grep -v $containerNameToExclude | cut -d ' ' -f 1)
    do
        _lxc_offer_to_stop_container $c
    done
}

_lxc_running_containers(){
    lxc-ls | grep RUNNING | cut -d ' ' -f 1
}

_lxc_frozen_containers(){
    lxc-ls | grep FROZEN | cut -d ' ' -f 1
}

_lxc_list_all_running_containers_and_offer_to_stop(){
    for c in $(_lxc_running_containers)
    do
        _lxc_offer_to_stop_container $c
    done
}

alias lxc-kill="_lxc_list_all_running_containers_and_offer_to_stop "

_lxc_attach_start_if_not_running_and_attach_as_user(){
    local containerName=$1
    local containerUser=${2:-$USER}
    local containerInfo="$(_lxc_validate_containerName $containerName)"
    if [[ "" == "$containerInfo" ]]
    then
        exit 1
    fi
    _lxc_list_running_containers_and_offer_to_stop $containerName
    if [[ "" == "$(echo $containerInfo | grep -v STOPPED)" ]]
    then
        echo "Starting container: $containerName"
        sudo lxc-start -n $containerName
    fi
    # this has been carefully crafted to work after many iterations. be warned
    sudo lxc-attach -n $containerName  -- /bin/su $containerUser -l -s /bin/bash
}
complete -F _lxc_containers_completion -o nospace lxc-attach
alias lxc-attach="_lxc_attach_start_if_not_running_and_attach_as_ec "