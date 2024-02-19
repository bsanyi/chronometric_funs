# ChronometricFuns

**ChronometricFuns** is a library that allows developers to define functions
with dynamic behavior based on specific points in time. By using this library,
you can write code that adapts to changing requirements as time progresses, or
makes it possible to deploy code ahead of time, that activates itself later.

## Description

The `ChronometricFuns` library provides macros that enable defining function
versions depending on activation points in time. These function versions can be
thought of as "alternate personalities" for the functions that get activated
based on _when_ they are called.

To use this library, import it into your module using the line `use
ChronometricFuns`. Then, you can define blocks such as `initially do ... end`
and `from <activation_point_in_time> do ... end` within your module.

* The `initially do ... end` block defines the default function versions that
  are active when no other `from` blocks are present. These functions act as
  fallbacks for all time points.  Another way to look at them is to define
  functions that are active from the beginning of time.
* The `from {point_in_time} do ... end` blocks contain alternate function
  definitions that get activated when the defined point in time (a Date or
  DateTime value) is reached. These versions can override the defaults from the
  `initially` block.  They can also override each other.

Function definitions within these blocks enable developers to write code that
dynamically adapts to changing requirements as time passes. The active function
version depends on the time of the call, allowing for greater flexibility and
dynamic behavior in your applications.

When calling functions defined using this library, Elixir checks which `from`
block should be active based on the current time point:

* If no `from` blocks have been reached (i.e., the current time is before all
  defined points), the functions within the `initially` block will be used.
* Once a `from` block's barrier is crossed, its function definitions become
  active and take precedence over any other `from` blocks or the `initially`
  block.
* An activated block does not overshadow the previous `from` block and the
  `initially` block.  It actually adds new function clauses in front of the
  clauses already present.


For example, consider two blocks:

```elixir
from ~D[2024-01-27] do
  def increase(0), do: 100
  def increase(n), do: n + 1
end

from ~D[2025-12-30] do
  def increase(n) when n > 0, do: a * 2
end
```

If you call the `increase` function on February 1, 2024, it will result in
adding 1 to the argument because the first `from` block is active at that time.
However, if you call this function after December 30, 2025 including that day,
the multiplication version of the `increase` function will be executed due to
the second `from` block being active.  When called with `0`, it will return
`100` in both cases.

## How to call the functions?

The preferred way of calling these scheduled functions is to use
`ChronometricFuns.apply/3`.  The function takes a module name as an atom, a
function name and a list of arguments.  It is a goop practise to add API
functions in order to reveal the functions as normal functions.

Another - but not recommended - way of calling these functions is to call tem
directly by denoting the time of the function call as the first argument of the
call.  For instance, the `increase/1` function defined above is actually a
2-arity function, that takes a unix timestamp as the first argument, and the
`n` value as the second.  Actually this is just implementation leaking out, so
I would suggest not using this method.


## How does this actually work?

What ChronometricFuns does in the background that is a bit hackie.  It defines
functions with an additional argument, that is the timestamp.  The
`ChronometricFuns.apply/3` function (ab)uses the process dictionary to store
the time the at which the functions are supposed to be evaluated.  `apply` uses
the value in the porcess dictionary if it presents, or it saves the current
time into the process dictionary if it does not hold a timestamp yet.  This
ensures that when your scheduled functions call each other using
`ChronometricFuns.apply/3`, the result is consistens, because all scheduled
functions are evaluated with the same timestamp.  This works fine as long as
you do separate calculations in separate processes, but makes testing harder in
the intereactive shell.


## Example usage

The `joe_is()` function has no arguments in this simple example, but it returns
different values based on the time of the call.

```elixir
defmodule Example do
  use ChronometricFuns

  def joe_is do
    ChronometricFuns.apply(__MODULE__, :joe_is, [])
  end

  initially do
    def joe_is, do: :not_jet_born
  end

  from ~D[1980-04-11] do
    def joe_is, do: :born
  end

  from ~D[1990-04-11] do
    def joe_is, do: :teenager
  end

  from ~D[2000-04-11] do
    def joe_is, do: :joung_adult
  end

  from ~D[2010-04-11] do
    def joe_is, do: :adult
  end

  from ~D[2043-02-27] do
    def joe_is, do: :old
  end
end

```

The following example demostrates that activated function definitions don't
just overwrite functions from previous blocks, but they can complement each
other by adding new function clauses.  Imagine the activation step like this:
an activated block puts it's function definitions as new clauses above the
already activated once.  It also demostrates that it is possible to use
`DateTime`s instead of `Date`s to label the `from` blocks.

```elixir
defmodule AnotherExample do
  use ChronometricFuns

  def number_to_string(n) do
    ChronometricFuns.apply(__MODULE__, :number_to_string, [n])
  end

  initially do
    def number_to_string(1), do: "one"
    def number_to_string(2), do: "two"
  end

  from ~U[2022-12-22 12:30:00Z] do
    def number_to_string(3), do: "three"
    def number_to_string(4), do: "four"
    def number_to_string(5), do: "five"
  end

  from ~U[2023-05-01 17:45:00Z] do
    def number_to_string(6), do: "six"
    def number_to_string(7), do: "seven"
  end
end
```

When one calls the `number_to_string` function in 2024, it exhibites all seven
clauses together:

    iex> Enum.map(1..7, &AnotherExample.number_to_string/1)
    ["one, "two", "three", "four", "five", "six", "seven"]

