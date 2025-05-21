(* OCaml module implementing a dynamic data processing pipeline with error handling *)

(* Define a type for data records, representing a simple key-value store *)
type record = {
  id : int;
  mutable data : (string * string) list;
}

(* Define a type for processing functions that can succeed or fail *)
type 'a processor = record -> ('a, string) result

(* Function to validate a record based on a predicate and error message *)
let validate predicate error_msg record =
  if predicate record then Ok () else Error error_msg

(* Function to apply a list of processors to a record, collecting errors *)
let rec process_record record processors errors =
  match processors with
  | [] -> (Ok (), errors)
  | p :: ps ->
    match p record with
    | Ok () -> process_record record ps errors
    | Error msg -> process_record record ps (msg :: errors)

(* Example processors:*)
let check_id_positive record =
  validate (fun r -> r.id > 0) "ID must be positive" record

let add_timestamp record =
  let timestamp = string_of_float (Unix.time ()) in
  record.data <- ("timestamp", timestamp) :: record.data;
  Ok ()

let uppercase_data_keys record =
  try
    let new_data = List.map (fun (k, v) -> (String.uppercase_ascii k, v)) record.data in
    record.data <- new_data; Ok ()
  with _ -> Error "Failed to uppercase data keys"

(* Dynamic filter:*)
let filter_records predicate records =
  List.filter predicate records

(* Example predicate to filter records with positive IDs*)
let is_valid_record record =
  record.id > 0

(* Main processing function *)
let process_records records =
  let processed_records = ref [] in
  List.iter (fun record ->
    let errors_accum = ref [] in
    match process_record record [check_id_positive; add_timestamp; uppercase_data_keys] errors_accum with
    | (Ok (), errs) -> (
        if errs <> [] then
          Printf.printf "Record ID %d processed with warnings: %s\n" record.id (String.concat "; " errs)
        else
          Printf.printf "Record ID %d processed successfully.\n" record.id;
        processed_records := record :: !processed_records
      )
    | (Error err, errs) ->
        Printf.printf "Error processing record ID %d: %s. Additional errors: %s\n" record.id err (String.concat "; " errs)

  ) records;
  !processed_records

(* Example usage:*)
let () =
  let records = [
    { id = 1; data = [("name", "Alice")] };
    { id = -2; data = [("name", "Bob")] };
    { id = 3; data = [("name", "Charlie")] }
  ] in
  let valid_records = filter_records (fun r -> r.id > 0) records in
  let _ = process_records valid_records in
  ()