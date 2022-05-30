Package["Wolfram`QuantumFramework`"]

PackageExport["QuantumCircuitOperator"]

PackageScope["QuantumCircuitOperatorQ"]



QuantumCircuitOperatorQ[QuantumCircuitOperator[KeyValuePattern[{"Operators" -> operators_, "Label" -> _}]]] :=
    VectorQ[Unevaluated @ operators, QuantumFrameworkOperatorQ]

QuantumCircuitOperatorQ[___] := False


(* constructors *)

QuantumCircuitOperator[operators_ /; VectorQ[operators, QuantumFrameworkOperatorQ]] :=
    QuantumCircuitOperator[<|"Operators" -> operators, "Label" -> RightComposition @@ (#["Label"] & /@ operators)|>]

QuantumCircuitOperator[operators_ /; VectorQ[operators, QuantumFrameworkOperatorQ], label_] :=
    QuantumCircuitOperator[<|"Operators" -> operators, "Label" -> label|>]

QuantumCircuitOperator[op : Except[_ ? QuantumCircuitOperatorQ, _ ? QuantumFrameworkOperatorQ], args___] := QuantumCircuitOperator[{op}, args]

QuantumCircuitOperator[op_ ? QuantumCircuitOperatorQ, args__] := QuantumCircuitOperator[op["Operators"], args]

QuantumCircuitOperator[qco_ ? QuantumCircuitOperatorQ | {qco_ ? QuantumCircuitOperatorQ}] := qco

QuantumCircuitOperator[params_List] := QuantumCircuitOperator[QuantumOperator @@ Replace[#, param : Except[_List] :> {param}] & /@ params]


(* composition *)

(qco_QuantumCircuitOperator ? QuantumCircuitOperatorQ)[op_ ? QuantumFrameworkOperatorQ] :=
    QuantumCircuitOperator[Prepend[qco["Operators"], op], qco["Label"][op["Label"]]]

(qco_QuantumCircuitOperator ? QuantumCircuitOperatorQ)[qs_ ? QuantumStateQ] := Fold[ReverseApplied[Construct], qs, qco["Operators"]]

op_QuantumMeasurementOperator[qco_QuantumCircuitOperator ? QuantumCircuitOperatorQ] :=
    QuantumCircuitOperator[Append[qco["Operators"], op], op["Label"][qco["Label"]]]


QuantumCircuitOperator /: comp : Composition[___ ? QuantumFrameworkOperatorQ, _QuantumCircuitOperator ? QuantumCircuitOperatorQ, ___ ? QuantumFrameworkOperatorQ] :=
With[{ops = List @@ Unevaluated[comp]},
    QuantumCircuitOperator[Flatten[Replace[qco_QuantumCircuitOperator :> qco["Operators"]] /@ Reverse @ ops, 1], Composition @@ (#["Label"] & /@ ops)]
]

QuantumCircuitOperator /: comp : RightComposition[___ ? QuantumFrameworkOperatorQ, _QuantumCircuitOperator ? QuantumCircuitOperatorQ, ___ ? QuantumFrameworkOperatorQ] :=
With[{ops = List @@ Unevaluated[comp]},
    QuantumCircuitOperator[Flatten[Replace[qco_QuantumCircuitOperator :> qco["Operators"]] /@ ops, 1], RightComposition @@ Reverse @ (#["Label"] & /@ ops)]
]


(* equality *)

QuantumCircuitOperator /: Equal[qco : _QuantumCircuitOperator ... ] := Equal @@ (#["CircuitOperator"] & /@ {qco})

