# boolexman
*__bool__ean __ex__pression __man__ipulator for educational purposes*

__boolexman__ is a boolean expression manipulator (program) to aid teaching
or studying propositional logic, primarily aimed for the [*Informatics 1 -
Computation and Logic*](http://www.inf.ed.ac.uk/teaching/courses/inf1/cl/)
at [The University of Edinburgh](https://www.ed.ac.uk/)
[School of Informatics](http://www.inf.ed.ac.uk/).

__boolexman__ offers various commands for working with boolean expressions,
from those that can transform any given expression into Disjunctive Normal Form
(*i.e.* an OR of ANDs) or Conjunctive Normal Form (*i.e.* an AND of ORs), to
those (functions) for fully-automated resolution, entailment, and
partial-evaluation. All commands shows *their working* step-by-step, with
detailed explanations of each rule that was used.

## Quick Manual
Each time you run __boolexman__, you will be greeted with a screen like follows:

```
boolexman - boolean expression manipulator | v0.1.0.0

   1>
```

`   1> ` is called *the prompt*, and it indicates that __boolexman__ is ready to
accept your command. The number before the greater-than symbol shows the
*command number*, which is provided only as a convenience to the user and has no
importance to the program at all. __boolexman__ uses Haskeline library to
provide a GNU Readline-like rich line-editing functionality to its users,
including moving backwards/forwards in the command history to Emacs/vi specific
key bindings, whose full list can be found on
[Haskeline Wiki](https://github.com/judah/haskeline/wiki/KeyBindings).

### Command Verbs
Every command to the __boolexman__ must start with a *command verb*, followed by
zero or more space-separated arguments. Every command verb starts with a letter,
followed by optionally some more alphanumeric characters. Command verbs are
case-insensitive!

- __`quit`__

  Quits the program. Takes no arguments.

- __`subexpressions`__ `expression :: Expression`

  Finds all the subexpressions of `expression`, including the `expression`
  itself.

  __Example:__

  ```
     1> subexpressions (if A iff B then C implies D xor E else F and G or not D)
  ```

  ```
      1 Sub-Expression Tree:
      2   ((A <=> B) ? (C => (D + E)) : ((F ^ G) v !D))
      3   ├─ (A <=> B)
      4   │  ├─ A
      5   │  ├─ B
      6   ├─ (C => (D + E))
      7   │  ├─ C
      8   │  ├─ (D + E)
      9   │  │  ├─ D
     10   │  │  ├─ E
     11   ├─ ((F ^ G) v !D)
     12   │  ├─ (F ^ G)
     13   │  │  ├─ F
     14   │  │  ├─ G
     15   │  ├─ !D
     16   │  │  ├─ D
     17
     18
     19 Sub-Expression List:
     20   • ((A <=> B) ? (C => (D + E)) : ((F ^ G) v !D))
     21   • (A <=> B)
     22   • A
     23   • B
     24   • (C => (D + E))
     25   • C   
     26   • (D + E)
     27   • D
     28   • E
     29   • ((F ^ G) v !D)
     30   • (F ^ G)
     31   • F
     32   • G
     33   • !D
  ```

- __`symbols`__ `expression :: Expression`

  Extracts all the symbols of `expression`.

  __Example:__

  ```
     1> symbols (if A iff B then C implies D xor E else F and G or not D)
  ```

  ```
     1 Symbols:
     2   • A
     3   • B
     4   • C
     5   • D
     6   • E
     7   • F
     8   • G
  ```

- __`eval`__ `symbols that are true :: List of Symbols` `symbols that are false :: List of Symbols` `expression :: Expression`

  Evaluates the `expression` given a set of `symbols that are true` and `symbols
  that are false`. If not every symbol in the `expression` appears in at least
  one of the sets, then the `expression` will be partially evaluated and the
  result will be in terms of those symbols that do not exists in neither set, in
  Disjunctive Normal Form.

  If some symbols that do not appear in the `expression` appear in one of the
  list of symbols, __boolexman__ will display a warning at the top of its
  output, but otherwise will work as intended.

  If some symbols appear in *both* lists of symbols, then __boolexman__ will
  display an error.

  __Example:__

  ```
     1> eval [A, D] [E] (if A iff B then C implies D xor E else F and G or not D)
  ```

  TODO: Update Output!
  ```
      1 First transform into CNF:
      2 ((A v !B v !D v F) ^ (A v !B v !D v G) ^ (B v !A v !D v F) ^ (B v !A v !D v G) ^ (!A v !B v !C v !D v !E) ^ (!A v !B v !C v D v E) ^ (A v B v !C v !D v !E) ^ (A v B v !C v D v E) ^ (!C v !D v !E v F) ^ (
      3
      4 Eliminate all maxterms which constains a true symbol:
      5   • [A,!B,!D,F]
      6     is eliminated because A is true.
      7   • [A,!B,!D,G]
      8     is eliminated because A is true.
      9   • [!A,!B,!C,!D,!E]
     10     is eliminated because !E is true.
     11   • [!A,!B,!C,D,E]
     12     is eliminated because D is true.
     13   • [A,B,!C,!D,!E]
     14     is eliminated because A is true.
     15   • [A,B,!C,D,E]
     16     is eliminated because A is true.
     17   • [!C,!D,!E,F]
     18     is eliminated because !E is true.
     19   • [!C,!D,!E,G]
     20     is eliminated because !E is true.
     21
     22
     23 After all:
     24 ((B v !A v !D v F) ^ (B v !A v !D v G))
     25
     26 Transform into DNF:
     27 (B v (B ^ !A) v (B ^ !D) v (B ^ G) v (!A ^ B) v !A v (!A ^ !D) v (!A ^ G) v (!D ^ B) v (!D ^ !A) v !D v (!D ^ G) v (F ^ B) v (F ^ !A) v (F ^ !D) v (F ^ G))
     28
     29 Eliminate all minterms which constains a false symbol:
     30   • [B,!A]
     31     is eliminated because !A is false.
     32   • [B,!D]
     33     is eliminated because !D is false.
     34   • [!A,B]
     35     is eliminated because !A is false.
     36   • [!A]
     37     is eliminated because !A is false.
     38   • [!A,!D]
     39     is eliminated because !A is false.
     40   • [!A,G]
     41     is eliminated because !A is false.
     42   • [!D,B]
     43     is eliminated because !D is false.
     44   • [!D,!A]
     45     is eliminated because !A is false.
     46   • [!D]
     47     is eliminated because !D is false.
     48   • [!D,G]
     49     is eliminated because !D is false.
     50   • [F,!A]
     51     is eliminated because !A is false.
     52   • [F,!D]
     53     is eliminated because !D is false.
     54
     55
     56 After all:
     57 (B v (B ^ G) v (F ^ B) v (F ^ G))
  ```



  ```
  quit

  help

  tabulate (P and Q and R or S implies T)

  subexpressions ((P and Q and R) or (S implies T))

  symbols ((P and Q and R) or (S implies T))

  eval [P, Q] [R, S, T] ((P and Q and R) or (S implies T))

  toDNF ((P and Q and R) or (S implies T))
  toCNF ((P and Q and R) or (S implies T))

  resolve (((P and Q and R) or (S implies T)))

  entail ((A implies (B and Q)) and (B implies C)) (A implies C)  -- gentzen
  ```

### Syntax

* __Command:__

## License
The ISC License, see [LICENSE](./LICENSE) for details.

Copyright (c) 2017 Mert Bora ALPER <bora@boramalper.org>

## Acknowledgements



__TODO:__
* entail (!True) (True => Q) fails!
* write quickchecks for every single command!
* Write manual!
* `prop_toCNF` and `prop_toDNF` are running very slowly, probably because of
  `toCNF` and `toDNF` are slow! Fix that.

quick manual:
    DONE  quit

          help

          tabulate (P and Q and R or S implies T)

    DONE  subexpressions ((P and Q and R) or (S implies T))

    DONE  symbols ((P and Q and R) or (S implies T))

    DONE  eval [P, Q] [R, S, T] ((P and Q and R) or (S implies T))

    DONE  toDNF ((P and Q and R) or (S implies T))
    DONE  toCNF ((P and Q and R) or (S implies T))

    DONE  resolve (((P and Q and R) or (S implies T)))

    DONE  entail ((A implies (B and Q)) and (B implies C)) (A implies C)  -- gentzen

syntax:

    command: <small letter>*
    symbol: <capital letter><small letter>*
    symbols: [symbol <, symbol>*]
    expression: (...)

    True and False are reserved symbols

ITE
IFF
IMP

operators (in order):

    not !
    and ^
    xor +
    or  v
    implies =>
    iff <=>
    if X then Y else Z  (X ? Y : Z)

    e.g. A ^ B <=> C v D => E + F ? C : D  is unambigous!

    A iff B <=> C

    e.g. A + B <=> C => D ^ (A v B) ? (A ? B : C) : B
         A+B<=>C=>D^(AvB)?(A?B:C):B
         if A xor B implies (C or D) and (A or B) then (if A then B else C) else B

regexes:

    (eval) \[([A-Z][a-zA-Z]*(?: *, *[A-Z][a-zA-Z]*)*)\] \[([A-Z][a-zA-Z]*(?: *, *[A-Z][a-zA-Z]*)*)\] \((.*)\)
