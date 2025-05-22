#!/bin/bash

declare -A queues
declare -A subscribers
declare -A message_ids
declare -A pending_messages

lockfile="/tmp/mq_backend.lock"

acquire_lock() {
  while ! mkdir "$lockfile" 2>/dev/null; do
    sleep 0.1
  done
}

release_lock() {
  rmdir "$lockfile"
}

initialize_queues() {
  for q in "$@"; do
    queues["$q"]=""
    subscribers["$q"]=()
    message_ids["$q"]=0
    pending_messages["$q"]=""
  done
}

create_queue() {
  local qname="$1"
  acquire_lock
  queues["$qname"]=""
  subscribers["$qname"]=()
  message_ids["$qname"]=0
  pending_messages["$qname"]=""
  release_lock
}

delete_queue() {
  local qname="$1"
  acquire_lock
  unset 'queues[$qname]' 'subscribers[$qname]' 'message_ids[$qname]' 'pending_messages[$qname]'
  release_lock
}

subscribe() {
  local qname="$1"
  local subscriber_id="$2"
  acquire_lock
  subscribers["$qname"]=("${subscribers[$qname]}" "$subscriber_id")
  release_lock
}

unsubscribe() {
  local qname="$1"
  local subscriber_id="$2"
  acquire_lock
  local new_subs=()
  for s in "${subscribers[$qname]}"; do
    if [[ "$s" != "$subscriber_id" ]]; then
      new_subs+=("$s")
    fi
  done
  subscribers["$qname"]="${new_subs[@]}"
  release_lock
}

send_message() {
  local qname="$1"
  local message="$2"
  acquire_lock
  ((message_ids["$qname"]++))
  local msg_id="${message_ids[$qname]}"
  local msg_entry="$msg_id|$message"
  pending_messages["$qname"]="${pending_messages[$qname]}$msg_entry"$'\n'
  release_lock
}

fetch_messages() {
  local qname="$1"
  local max_messages="$2"
  local msgs=()
  acquire_lock
  IFS=$'\n' read -d '' -r -a all_msgs <<<"${pending_messages[$qname]}"
  local count=0
  for msg in "${all_msgs[@]}"; do
    if (( count >= max_messages )); then
      break
    fi
    IFS='|' read -r id payload <<<"$msg"
    msgs+=("$id|$payload")
    ((count++))
  done
  release_lock
  printf '%s\n' "${msgs[@]}"
}

acknowledge() {
  local qname="$1"
  local msg_id="$2"
  acquire_lock
  IFS=$'\n' read -d '' -r -a all_msgs <<<"${pending_messages[$qname]}"
  local new_msgs=()
  for msg in "${all_msgs[@]}"; do
    IFS='|' read -r id payload <<<"$msg"
    if [[ "$id" != "$msg_id" ]]; then
      new_msgs+=("$msg")
    fi
  done
  IFS=$'\n'; pending_messages["$qname"]="${new_msgs[*]}"
  release_lock
}

list_queues() {
  acquire_lock
  printf '%s\n' "${!queues[@]}"
  release_lock
}

list_subscribers() {
  local qname="$1"
  acquire_lock
  printf '%s\n' "${subscribers[$qname]}"
  release_lock
}

main() {
  initialize_queues "queue1" "queue2" "queue3"
  subscribe "queue1" "sub1"
  subscribe "queue1" "sub2"
  send_message "queue1" "Hello World"
  send_message "queue1" "Another Message"
  fetch_messages "queue1" 10
  acknowledge "queue1" "1"
  list_queues
  list_subscribers "queue1"
  delete_queue "queue2"
  create_queue "queue4"
}

main "$@"