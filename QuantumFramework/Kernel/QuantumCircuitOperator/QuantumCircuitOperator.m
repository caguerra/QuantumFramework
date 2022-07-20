Package["Wolfram`QuantumFramework`"]

PackageExport["QuantumCircuitOperator"]

PackageScope["QuantumCircuitOperatorQ"]



QuantumCircuitOperatorQ[QuantumCircuitOperator[KeyValuePattern[{"Operators" -> operators_, "Label" -> _}]]] :=
    VectorQ[Unevaluated @ operators, QuantumFrameworkOperatorQ]

QuantumCircuitOperatorQ[___] := False


(* constructors *)

QuantumCircuitOperator[operators_ /; VectorQ[operators, QuantumFrameworkOperatorQ]] :=
    QuantumCircuitOperator[<|"Operators" -> operators, "Label" -> RightComposition @@ (#["Label"] & /@ operators)|>]

QuantumCircuitOperator[operators_ /; VectorQ[operators, QuantumFrameworkOperatorQ], label_, ___] :=
    QuantumCircuitOperator[<|"Operators" -> operators, "Label" -> label|>]

QuantumCircuitOperator[op : Except[_ ? QuantumCircuitOperatorQ, _ ? QuantumFrameworkOperatorQ], args___] := QuantumCircuitOperator[{op}, args]

QuantumCircuitOperator[op_ ? QuantumCircuitOperatorQ, args__] := QuantumCircuitOperator[op["Operators"], args]

QuantumCircuitOperator[qco_ ? QuantumCircuitOperatorQ | {qco_ ? QuantumCircuitOperatorQ}] := qco

QuantumCircuitOperator[params: Except[{Alternatives @@ $QuantumCircuitOperatorNames, ___}, _List]] :=
    Enclose @ QuantumCircuitOperator[ConfirmBy[QuantumOperator[#], QuantumOperatorQ] & @@ Replace[#, param : Except[_List] :> {param}] & /@ params]


(* composition *)

(qco_QuantumCircuitOperator ? QuantumCircuitOperatorQ)[op_ ? QuantumFrameworkOperatorQ] :=
    QuantumCircuitOperator[Prepend[qco["Operators"], op], qco["Label"][op["Label"]]]

Options[quantumCircuitApply] = {Method -> Automatic}

quantumCircuitApply[qco_QuantumCircuitOperator, qs_QuantumState, OptionsPattern[]] :=
    Switch[
        OptionValue[Method],
        "Schrodinger" | "Schroedinger" | "Schrödinger",
        Fold[ReverseApplied[Construct], qs, qco["Operators"]],
        Automatic | "TensorNetwork",
        Block[{
            state = If[
                qs["PureStateQ"],
                QuantumState[SparseArrayFlatten[#], TensorDimensions[#], "Label" -> qs["Label"] /* qco["Label"]] & @
                    ContractTensorNetwork @ InitializeTensorNetwork[
                        qco["TensorNetwork"],
                        qs["Computational"]["Tensor"],
                        Join[Superscript[0, #] & /@ (Range[qs["OutputQudits"]]), Subscript[0, #] & /@ (Range[qs["InputQudits"]])]
                    ],
                QuantumState[
                    (qco["Dagger"] /* qs["Operator"] /* qco)["QuantumOperator", Method -> "TensorNetwork"]["Unbend"],
                    "Label" -> qs["Label"] /* qco["Label"]
                ]
            ]
        },
            If[ qco["Channels"] > 0,
                state = QuantumPartialTrace[state,
                    First @ Fold[
                        {
                            Join[#1[[1]], If[QuantumChannelQ[#2], #1[[2]] + Range[#2["TraceQudits"]], {}]],
                             #1[[2]] + Which[QuantumChannelQ[#2], #2["TraceQudits"], QuantumMeasurementOperatorQ[#2], #2["Eigenqudits"], True, 0]
                        } &,
                        {{}, 0},
                        qco["Operators"]
                    ]
                ]
            ];
            If[ qco["Measurements"] > 0,
                QuantumMeasurement[QuantumMeasurementOperator[QuantumOperator[state, Range[state["Qudits"]] - qco["Eigenqudits"]], qco["Target"]]],
                state
            ]
        ],
        _,
        $Failed
    ]

(qco_QuantumCircuitOperator ? QuantumCircuitOperatorQ)[qs_ ? QuantumStateQ, opts : OptionsPattern[quantumCircuitApply]] := quantumCircuitApply[qco, qs, opts]

(qco_QuantumCircuitOperator ? QuantumCircuitOperatorQ)[opts : OptionsPattern[quantumCircuitApply]] := qco[QuantumState[{"Register", qco["Width"]}], opts]


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

QuantumCircuitOperator /: Equal[left___, qco_QuantumCircuitOperator, right___] :=
    Equal @@ (If[QuantumCircuitOperatorQ[#], #["CircuitOperator"], #] & /@ {left, qco, right})


(* part *)

Part[qco_QuantumCircuitOperator, part_] ^:= QuantumCircuitOperator[qco["Operators"][[part]], qco["Label"]]

