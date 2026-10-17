---
name: ios-api-endpoint
description: Add or change an API call in this iOS codebase — an Endpoint, its wire models, the repository method that calls it, and the tests. Use when asked to wire up a new backend call, integrate an API endpoint, change a request or response shape, add a query parameter or filter, handle a new error response, or when the backend contract has changed and the app must follow.
---

# Add an API call

## Where the pieces go

| Piece | Location |
| --- | --- |
| The call as data | `Features/<X>/Data/<X>Endpoints.swift` |
| Request/response models | Beside the endpoint, `private` if only used there |
| The method callers use | `<X>Repository` protocol + `Live<X>Repository` |
| Cache key, if cached | `<X>CacheKeys` |
| Tests | `AppTemplateTests/Features/<X>RepositoryTests.swift` |

Never call `client.send` from a view model or a view. The repository is the only
caller.

## Steps

1. **Write the endpoint.**

   ```swift
   static func list(page: PageRequest = .first, search: String? = nil) -> Endpoint {
       var query = page.queryItems
       if let search, search.trimmingCharacters(in: .whitespaces).isEmpty == false {
           query.append(URLQueryItem(name: "q", value: search))
       }
       return .get("widgets", query: query)
   }

   static func create(_ draft: WidgetDraft) throws -> Endpoint {
       try .post("widgets", body: draft)
   }
   ```

   - Path is relative with no leading slash.
   - `requiresAuthentication: false` only for genuinely public calls.
   - Body factories throw (encoding); the repository method is `throws` anyway.

2. **Model the response.** Plain `Decodable` with camelCase properties —
   `JSONDecoder.api` converts `snake_case` keys automatically, so `CodingKeys` is
   usually unnecessary. Only enum *raw values* need to match the wire exactly.
   - Collections use `Page<Item>`.
   - 204 / empty bodies use the non-generic `send(_:)`, or `EmptyResponse`.
   - Optional server fields are `Optional` in the model. Do not paper over a
     missing field with a default unless the contract says it may be absent.

3. **Add the repository method.** Protocol first, then the implementation:
   store to cache and invalidate the list where relevant, and catch
   `error.isConnectivityFailure` if the operation is offline-capable.

4. **Handle new error semantics.** If the endpoint returns a status with meaning
   the app must act on, check `APIError` already distinguishes it, then make sure
   `AppError.from(_:)` phrases it for a person. Do not add error copy in a view.

5. **Test it** with `StubAPIClient` keyed `"METHOD /path"`, or with
   `StubHTTPSession` and a real `LiveAPIClient` when the test is about transport
   behaviour (status mapping, retry, refresh).

## Verification

- [ ] Decoding tested against a realistic payload, including `snake_case` keys and
      an ISO 8601 date.
- [ ] Failure path tested — at least the one status this endpoint can realistically
      return (404, 409, 422).
- [ ] Query values are not logged (`Endpoint.logDescription` omits them; keep it
      that way).
- [ ] No credentials or tokens in the endpoint, headers or test fixtures.
- [ ] The call is reachable only through the repository.
