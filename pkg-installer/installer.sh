#!/usr/bin/env bash
#
# installer.sh
#
# Установка зависимостей из JSON дерева.
#

set -euo pipefail


################################################################################
# build_install_plan
#
# Определяет менеджер для каждого пакета.
#
# Output:
# package<TAB>manager
# package<TAB>missing
#
################################################################################

build_install_plan()
{
    local preferred_manager="${1:-auto}"

    shift || true


    local -a package_list=("$@")


    local -a manager_list=()



    mapfile -t manager_list < <(
        resolve_managers "$preferred_manager"
    )



    local package

    local manager

    local checker

    local installer

    local found



    for package in "${package_list[@]}"; do


        found=false



        for manager in "${manager_list[@]}"; do


            IFS=' ' read -r checker installer <<< "${MANAGERS[$manager]}"



            if "$checker" "$package"; then


                printf '%s\t%s\n' \
                    "$package" \
                    "$manager"


                found=true


                break

            fi


        done



        if [[ "$found" == false ]]; then


            printf '%s\tmissing\n' \
                "$package"


        fi


    done

}



################################################################################
# group_packages_by_manager
#
# Группировка пакетов по менеджерам.
#
################################################################################

group_packages_by_manager()
{
    local output_array="$1"

    shift || true



    declare -n target_ref="$output_array"



    local item

    local package

    local manager



    for item in "$@"; do


        IFS=$'\t' read -r package manager <<< "$item"



        [[ -z "$package" ]] && continue



        if [[ ${target_ref[$manager]+_} ]]; then


            target_ref[$manager]+=" $package"


        else


            target_ref[$manager]="$package"


        fi


    done

}



################################################################################
# write_missing_packages
#
# Запись отсутствующих пакетов.
#
################################################################################
write_missing_packages()
{
    local block="${1:-unknown}"
    local manager="${2:-auto}"
    local package_string="${3:-}"

    [[ -z "$package_string" ]] && return 0

    local package

    for package in $package_string; do
        missing_write \
"$(date '+%Y-%m-%d %H:%M:%S') | file=${DEPENDENCIES_FILE:-unknown} | block=$block | manager=$manager | package=$package"
    done
}

################################################################################
# parallel_install_groups
#
# Параллельная установка пакетов.
#
################################################################################
parallel_install_groups()
{
    local input_array="$1"



    declare -n target_ref="$input_array"



    declare -A process_map=()



    local manager

    local checker

    local installer

    local pid



    local -a package_list



    local result=0



    for manager in "${!target_ref[@]}"; do


        IFS=' ' read -r checker installer <<< "${MANAGERS[$manager]}"



        read -ra package_list <<< "${target_ref[$manager]}"



        if [[ "$DRY_RUN" == true ]]; then


            log_info \
                "[DRY-RUN][$manager] ${package_list[*]}"


            continue


        fi



        log_info \
            "[$manager] Installing ${package_list[*]}"



        (
            "$installer" "${package_list[@]}"
        ) &



        pid=$!


        process_map[$manager]=$pid


    done



    for manager in "${!process_map[@]}"; do


        pid="${process_map[$manager]}"



        if wait "$pid"; then


            log_info \
                "[$manager] Installation completed"


        else


            log_error \
                "[$manager] Installation failed"


            result=1


        fi


    done



    return "$result"

}



################################################################################
# install_block
#
# Установка одного блока.
#
################################################################################
install_block()
{
    local block="${1:-unknown}"

    local preferred_manager="${2:-auto}"



    shift 2 || true



    local -a package_list=("$@")



    declare -A manager_packages=()



    local -a install_plan=()



    log_info \
        "Processing block: $block"



    mapfile -t install_plan < <(
        build_install_plan \
            "$preferred_manager" \
            "${package_list[@]}"
    )



    group_packages_by_manager \
        manager_packages \
        "${install_plan[@]}"



    if [[ ${manager_packages[missing]+_} ]]; then


        log_warn \
            "Missing package(s): ${manager_packages[missing]}"



        write_missing_packages \
            "$block" \
            "$preferred_manager" \
            "${manager_packages[missing]}"



        unset 'manager_packages[missing]'


    fi



    if (( ${#manager_packages[@]} == 0 )); then

        return 0

    fi



    parallel_install_groups \
        manager_packages

}

################################################################################
# install_dependency_tree
#
# Обход дерева зависимостей.
#
################################################################################
install_dependency_tree()
{
    local json_file="$1"



    DEPENDENCIES_FILE="$json_file"



    local object



    while IFS= read -r object; do


        local block

        local manager


        block=$(jq -r '.block' <<< "$object")

        manager=$(jq -r '.manager' <<< "$object")



        local -a package_list=()



        mapfile -t package_list < <(
            jq -r '.packages[]' <<< "$object"
        )



        install_block \
            "$block" \
            "$manager" \
            "${package_list[@]}"


    done < <(
        parse_json_dependencies "$json_file"
    )

}

################################################################################
# show_install_report
#
# Финальный отчёт.
#
################################################################################
show_install_report()
{
    if missing_exists; then

        log_warn "Missing packages found"
        log_warn "Report: $MISSING_FILE"

    else

        log_info "All packages processed successfully"

    fi
}
