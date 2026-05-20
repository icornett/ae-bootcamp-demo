# Patterns Discovered

Capture recurring implementation patterns and keep them updated over time.

## Pattern Template

### Pattern: <name>

Context:

- Where this pattern appears.

Problem:

- What issue this pattern solves.

Solution:

- Preferred approach.

Example:

```text
Add a concise example snippet or command sequence.
```

Related files:

- path/to/file
- path/to/another-file

---

## Example Pattern

### Pattern: Service initialization (empty array vs null)

Context:

- Service state initialization in app startup and test setup.

Problem:

- `null` initialization forces repeated nil checks and can cause runtime errors when consumers expect iterable collections.

Solution:

- Initialize list-like service state with an empty array to guarantee safe iteration and predictable defaults.

Example:

```ruby
# Preferred
service.items = []

# Avoid unless explicitly modeling absence
service.items = nil
```

Related files:

- blog/workouts.rb
- blog/spec/unit
