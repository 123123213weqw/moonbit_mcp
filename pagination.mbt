///|
/// A paginated result carrying an optional cursor for the next page.
pub(all) struct Paginated[T] {
  items : Array[T]
  next_cursor : String?
} derive(Debug, Eq)

///|
/// Construct a paginated result with no next cursor.
pub fn[T] Paginated::new(items : Array[T]) -> Paginated[T] {
  { items, next_cursor: None }
}

///|
/// Construct a paginated result with a next cursor.
pub fn[T] Paginated::with_cursor(
  items : Array[T],
  cursor : String,
) -> Paginated[T] {
  { items, next_cursor: Some(cursor) }
}
