#!/usr/bin/env bash
#
# parser.sh
#
# Разбор дерева зависимостей.
#
# Обход дерева выполняется средствами jq.
#
# Поддерживается наследование:
#
#   manager
#   enabled
#
# Поддерживается произвольная глубина вложенности.
#

################################################################################
# parse_json_dependencies
################################################################################

##
# Разбирает JSON-файл зависимостей.
#
# Parameters:
#   $1 JSON file
#
# Output:
#
# Каждая строка представляет JSON-объект вида
#
# {
#   "block":"fonts.nerd",
#   "manager":"yay",
#   "packages":[...]
# }
#
parse_json_dependencies() {

    local file="$1"

    jq -c '
    def walk(node; path; manager; enabled):

        if (node | type) != "object" then
            empty

        else

            (
                node.manager // manager // "auto"
            ) as $manager

            |

            (
                node.enabled // enabled // true
            ) as $enabled

            |

            if $enabled == false then
                empty

            else

                (
                    if node.packages? then

                        {
                            block:
                                (
                                    path
                                    | join(".")
                                ),

                            manager:$manager,

                            packages:node.packages
                        }

                    else
                        empty
                    end
                ),

                (

                    node

                    | to_entries[]

                    | select(
                        (.value | type) == "object"
                    )

                    | select(
                        .key != "packages"
                    )

                    | select(
                        .key != "manager"
                    )

                    | select(
                        .key != "enabled"
                    )

                    | walk(
                        .value;
                        path + [.key];
                        $manager;
                        $enabled
                    )

                )

            end

        end;

    walk(
        .;
        [];
        "auto";
        true
    )
    ' "$file"
}

################################################################################
# install_dependency_tree
################################################################################

##
# Устанавливает дерево зависимостей.
#
# Parameters:
#   $1 JSON file
#
install_dependency_tree() {

    local file="$1"

    local block
    local manager

    local -a packages

    while IFS= read -r object; do

        block="$(
            jq -r '.block' <<<"$object"
        )"

        manager="$(
            jq -r '.manager' <<<"$object"
        )"

        mapfile -t packages < <(
            jq -r '.packages[]' <<<"$object"
        )

        install_block \
            "$block" \
            "$manager" \
            "${packages[@]}"

    done < <(
        parse_json_dependencies "$file"
    )
}