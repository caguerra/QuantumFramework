Package["Wolfram`QuantumFramework`"]

PackageScope["$QuantumCircuitOperatorNames"]



$QuantumCircuitOperatorNames = {"Graph", "GroverDiffusion", "BooleanOracle", "Toffoli"}


QuantumCircuitOperator[{"Graph", g_Graph}] := QuantumCircuitOperator[QuantumOperator["CZ", {#1, #2}] & @@@ EdgeList[IndexGraph @ g], "\[ScriptCapitalG]"]


QuantumCircuitOperator[{"GroverAmplification" | "GroverDiffusion", xs : {_Integer ? Positive..}, m : _Integer ? Positive | Automatic | None : Automatic}] := Module[{
    target = Replace[m, Automatic -> Max[xs]],
    ys
},
    ys = DeleteCases[xs, target];
    QuantumCircuitOperator[{
        Splice[Table[QuantumOperator["H", {q}], {q, ys}]],
        Splice[Table[QuantumOperator["X", {q}], {q, ys}]],
        QuantumOperator[{"Controlled", "NOT", ys}, {target}],
        Splice[Table[QuantumOperator["X", {q}], {q, ys}]],
        Splice[Table[QuantumOperator["H", {q}], {q, ys}]]
    }]
]

QuantumCircuitOperator[{"GroverAmplification0" | "GroverDiffusion0", xs : {_Integer ? Positive..}, m : _Integer ? Positive | Automatic | None : Automatic}] := Module[{
    target = Replace[m, Automatic -> Max[xs]],
    ys
},
    ys = DeleteCases[xs, target];
    QuantumCircuitOperator[{
        Splice[Table[QuantumOperator["H", {q}], {q, ys}]],
        QuantumOperator[{"Controlled0", "NOT", ys}, {target}],
        Splice[Table[QuantumOperator["H", {q}], {q, ys}]]
    }]
]

QuantumCircuitOperator[{name : "GroverAmplification" | "GroverAmplification0" | "GroverDiffusion" | "GroverDiffusion0",
    n_Integer ? Positive, m : _Integer ? Positive | Automatic : Automatic}] :=
    QuantumCircuitOperator[{name, Range[n], m}]

QuantumCircuitOperator[{"GroverOperator" | "Grover", oracle_ ? QuantumFrameworkOperatorQ /; ContainsExactly[oracle["InputOrder"], oracle["OutputOrder"]], m : _Integer ? Positive | Automatic | None : Automatic}] :=
    With[{n = Replace[m, Automatic -> Max[oracle["OutputOrder"]]]},
        QuantumCircuitOperator[{"GroverDiffusion", oracle["OutputOrder"], n}][oracle]
    ]

QuantumCircuitOperator[{"GroverOperator0" | "Grover0", oracle_ ? QuantumFrameworkOperatorQ /; ContainsExactly[oracle["InputOrder"], oracle["OutputOrder"]], m : _Integer ? Positive | Automatic | None : Automatic}] :=
    With[{n = Replace[m, Automatic -> Max[oracle["OutputOrder"]]]},
        QuantumCircuitOperator[{"GroverDiffusion0", oracle["OutputOrder"], n}][oracle]
    ]


QuantumCircuitOperator[{"BooleanOracle", formula_, defaultVars : _List | Automatic : Automatic, n : _Integer ? NonNegative : 0}] := Enclose @ Module[{
    esop = Confirm[BooleanConvert[formula, "ESOP"]] /. And -> List,
    vars = Replace[defaultVars, Automatic -> BooleanVariables[formula]],
    indices, targetQubits
},
    esop = Replace[esop, clause : Except[_Xor] :> {clause}]  /. Xor -> List;
    esop = Replace[esop, clause : Except[_List] :> {clause}, {1}];
	indices = <|0 -> {}, 1 -> {}, PositionIndex @ Lookup[#, vars]|> & /@ Map[If[MatchQ[#, _Not], #[[1]] -> 0, # -> 1] &, esop, {2}];
    targetQubits = {Max[Length[vars] + 1, n]};
	QuantumCircuitOperator[QuantumOperator[{"Controlled", "NOT", #[1], #[0]}, targetQubits] & /@ indices, formula]
]

QuantumCircuitOperator[{"BooleanOracle", formula_, vars : KeyValuePattern[_ -> _Integer ? Positive], n : _Integer ? NonNegative : 0}] :=
    QuantumCircuitOperator[{"BooleanOracle", formula, Lookup[Reverse /@ Normal @ vars, Range[Max[vars]]], n}]



QuantumCircuitOperator["Toffoli"] := QuantumCircuitOperator[{"Toffoli", 1}]

QuantumCircuitOperator[{"Toffoli", n : _Integer ? Positive : 1}] := QuantumCircuitOperator[{
    QuantumOperator["H", {n + 2}],
    QuantumOperator["CNOT", {n + 1, n + 2}],
    QuantumOperator["T", {n + 2}]["Dagger"],
    QuantumOperator["CNOT", {n, n + 2}],
    QuantumOperator["T", {n + 2}],
    QuantumOperator["CNOT", {n + 1, n + 2}],
    QuantumOperator["T", {n + 2}]["Dagger"],
    QuantumOperator["CNOT", {n, n + 2}],
    QuantumOperator["T", {n + 1}]["Dagger"],
    QuantumOperator["T", {n + 2}],
    QuantumOperator["H", {n + 2}],
    QuantumOperator["CNOT", {n, n + 1}],
    QuantumOperator["T", {n + 1}]["Dagger"],
    QuantumOperator["CNOT", {n, n + 1}],
    QuantumOperator["T", {n}],
    QuantumOperator["S", {n + 1}]
}]

