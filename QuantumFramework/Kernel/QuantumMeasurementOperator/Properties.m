Package["Wolfram`QuantumFramework`"]



$QuantumMeasurementOperatorProperties = {
    "QuantumOperator", "Targets", "Target", "TargetCount",
    "TargetIndex",
    "Operator", "Basis", "MatrixRepresentation", "POVMElements",
    "OrderedMatrixRepresentation", "OrderedPOVMElements",
    "Arity", "Eigenqudits", "Dimensions", "Order", "HermitianQ", "UnitaryQ", "Eigenvalues", "Eigenvectors",
    "Eigendimensions", "Eigendimension",
    "StateDimensions", "StateDimension",
    "TargetDimensions", "TargetDimension",
    "StateQudits", "TargetBasis", "StateBasis", "CanonicalBasis", "Canonical",
    "ProjectionQ", "POVMQ",
    "SuperOperator", "POVM",
    "Shift"
};


QuantumMeasurementOperator["Properties"] := Union @ Join[
    $QuantumMeasurementOperatorProperties,
    $QuantumOperatorProperties
]

qmo_QuantumMeasurementOperator["ValidQ"] := QuantumMeasurementOperatorQ[qmo]


QuantumMeasurementOperator::undefprop = "QuantumMeasurementOperator property `` is undefined for this operator";


(qmo_QuantumMeasurementOperator[prop_ ? propQ, args___]) /; QuantumMeasurementOperatorQ[qmo] := With[{
    result = QuantumMeasurementOperatorProp[qmo, prop, args]
    },
    If[ TrueQ[$QuantumFrameworkPropCache] &&
        ! MemberQ[{"Properties", "QuantumOperator", "Operator"}, prop] &&
        QuantumMeasurementOperatorProp[qmo, "Basis"]["ParameterArity"] == 0,
        QuantumMeasurementOperatorProp[qmo, prop, args] = result,
        result
    ] /; !FailureQ[Unevaluated @ result] && (!MatchQ[result, _QuantumMeasurementOperatorProp] || Message[QuantumMeasurementOperator::undefprop, prop])
]

CacheProperty[QuantumMeasurementOperator][args___, value_] := PrependTo[
    DownValues[QuantumMeasurementOperatorProp],
    HoldPattern[QuantumMeasurementOperatorProp[args]] :> value
]

QuantumMeasurementOperatorProp[qmo_, "Properties"] :=
    DeleteDuplicates @ Join[QuantumMeasurementOperator["Properties"], qmo["Operator"]["Properties"]]


(* getters *)

QuantumMeasurementOperatorProp[_[op_, _], "Operator" | "QuantumOperator"] := op

QuantumMeasurementOperatorProp[_[_, targets_], "Targets"] := targets

QuantumMeasurementOperatorProp[qmo_, "Target" | "TargetOrder"] := Join @@ qmo["Targets"]

QuantumMeasurementOperatorProp[qmo_, "Arity" | "TargetCount"] := Length[qmo["Target"]]

QuantumMeasurementOperatorProp[qmo_, "Eigenorder"] := Replace[Select[qmo["FullOutputOrder"], NonPositive], {} -> {0}]

QuantumMeasurementOperatorProp[qmo_, "Eigenindex"] :=
    Catenate @ Position[qmo["FullOutputOrder"], _ ? NonPositive, {1}]

QuantumMeasurementOperatorProp[qmo_, "TargetIndex"] :=
    Catenate @ Lookup[PositionIndex[qmo["FullOutputOrder"]], qmo["Target"]]

QuantumMeasurementOperatorProp[qmo_, "TargetDimensions"] :=
    Part[qmo["OutputDimensions"], qmo["TargetIndex"]]

QuantumMeasurementOperatorProp[qmo_, "TargetDimension"] := Times @@ qmo["TargetDimensions"]

QuantumMeasurementOperatorProp[qmo_, "ExtraQudits"] := Count[qmo["OutputOrder"], _ ? NonPositive]

QuantumMeasurementOperatorProp[qmo_, "Eigenqudits"] := Max[qmo["ExtraQudits"], 1]

QuantumMeasurementOperatorProp[qmo_, "Eigendimensions"] :=
    If[qmo["ExtraQudits"] > 0, qmo["OutputDimensions"][[qmo["Eigenindex"]]], {Times @@ qmo["OutputDimensions"][[qmo["TargetIndex"]]]}]

QuantumMeasurementOperatorProp[qmo_, "Eigendimension"] := Times @@ qmo["Eigendimensions"]

QuantumMeasurementOperatorProp[qmo_, "Eigenbasis"] := qmo["Output"]["Extract", qmo["Eigenindex"]]

QuantumMeasurementOperatorProp[qmo_, "StateQudits"] := qmo["OutputQudits"] - qmo["ExtraQudits"]

QuantumMeasurementOperatorProp[qmo_, "StateDimensions"] := Drop[qmo["Dimensions"], qmo["ExtraQudits"]]

QuantumMeasurementOperatorProp[qmo_, "StateDimension"] := Times @@ qmo["StateDimensions"]

QuantumMeasurementOperatorProp[qmo_, "TargetBasis"] := qmo["Output"]["Extract", qmo["TargetIndex"]]

QuantumMeasurementOperatorProp[qmo_, "StateBasis"] :=
    QuantumBasis[qmo["Basis"], "Output" -> Last @ qmo["Output"]["Split", qmo["ExtraQudits"]], "Input" -> qmo["Input"]]

QuantumMeasurementOperatorProp[qmo_, "CanonicalBasis"] :=
    QuantumBasis[qmo["Basis"], "Output" -> QuantumTensorProduct[qmo["TargetBasis"]["Reverse"], qmo["StateBasis"]["Output"]], "Input" -> qmo["Input"]]


canonicalEigenPermutation[qmo_] := Block[{accumIndex = PositionIndex[FoldList[Times, qmo["TargetDimensions"]]]},
	FindPermutation @ Catenate[
        Reverse /@ TakeList[
            Range[qmo["TargetCount"]],
            Reverse @ Differences @ Prepend[0] @ Catenate @ Lookup[accumIndex, FoldList[Times, Reverse[qmo["Eigendimensions"]]]]
        ]
    ]
]

QuantumMeasurementOperatorProp[qmo_, "Canonical", OptionsPattern[{"Reverse" -> True}]] /; qmo["Eigendimension"] == qmo["TargetDimension"] := With[{
    basis = qmo["CanonicalBasis"], perm = canonicalEigenPermutation[qmo]
},
    QuantumMeasurementOperator[
        QuantumOperator[
            QuantumState[
                QuantumState[
                    qmo["SuperOperator"]["State"],
                    QuantumBasis[Join[Permute[Reverse[qmo["TargetDimensions"]], InversePermutation[perm]], qmo["StateBasis"]["OutputDimensions"]], basis["InputDimensions"]]
                ]["PermuteOutput", perm],
                basis
            ]["PermuteOutput", PermutationProduct[
                FindPermutation[Reverse[qmo["Target"]], ReverseSort[qmo["Target"]]],
                If[TrueQ[OptionValue["Reverse"]], FindPermutation[Reverse[Range[qmo["TargetCount"]]]], Cycles[{}]]
            ]],
            {Join[Range[- qmo["TargetCount"] + 1, 0], DeleteCases[qmo["OutputOrder"], _ ? NonPositive]], qmo["InputOrder"]}
        ],
        Sort @ qmo["Target"]
    ]
]

QuantumMeasurementOperatorProp[qmo_, "Canonical", OptionsPattern[{"Reverse" -> True}]] /; Length[qmo["Eigenorder"]] == qmo["TargetCount"] := QuantumMeasurementOperator[
        QuantumOperator[
            qmo["SuperOperator"]["State"]["PermuteOutput", PermutationProduct[
                FindPermutation[Reverse[qmo["Target"]], ReverseSort[qmo["Target"]]],
                If[TrueQ[OptionValue["Reverse"]], FindPermutation[Reverse[Range[qmo["TargetCount"]]]], Cycles[{}]]
            ]],
            {Join[Range[- qmo["TargetCount"] + 1, 0], DeleteCases[qmo["OutputOrder"], _ ? NonPositive]], qmo["InputOrder"]}
        ],
        Sort @ qmo["Target"]
    ]

QuantumMeasurementOperatorProp[qmo_, "Canonical", OptionsPattern[{"Reverse" -> True}]] := QuantumMeasurementOperator[
        QuantumOperator[
            qmo["SuperOperator"]["State"]["PermuteOutput",
                If[TrueQ[OptionValue["Reverse"]], FindPermutation[Reverse[Range[qmo["Eigenqudits"]]]], Cycles[{}]]
            ],
            {Join[Range[- qmo["Eigenqudits"] + 1, 0], DeleteCases[qmo["OutputOrder"], _ ? NonPositive]], qmo["InputOrder"]}
        ],
        qmo["Target"]
    ]


QuantumMeasurementOperatorProp[qmo_, "SortTarget"] := qmo["Canonical", "Reverse" -> False]


QuantumMeasurementOperatorProp[qmo_, "ReverseEigenQudits"] := QuantumMeasurementOperator[
    QuantumOperator[
        qmo["SuperOperator"]["State"]["PermuteOutput", FindPermutation[Reverse[Range[qmo["Eigenqudits"]]]]],
        qmo["Order"]
    ],
    qmo["Targets"]
]


QuantumMeasurementOperatorProp[qmo_, "Type"] := Which[
    Count[qmo["OutputOrder"], _ ? NonPositive] == 0 && qmo["OutputDimensions"] == qmo["InputDimensions"],
    "Projection",
    Count[qmo["OutputOrder"], _ ? NonPositive] > 0,
    "POVM",
    True,
    "Unknown"
]

QuantumMeasurementOperatorProp[qmo_, "ProjectionQ"] := qmo["Type"] === "Projection"

QuantumMeasurementOperatorProp[qmo_, "POVMQ"] := qmo["Type"] === "POVM"

QuantumMeasurementOperatorProp[qmo_, "POVMElements"] := If[qmo["POVMQ"], # . ConjugateTranspose[#] & /@ qmo["Tensor"], qmo["Projectors", "Sort" -> True]]

QuantumMeasurementOperatorProp[qmo_, "OrderedPOVMElements"] := If[qmo["POVMQ"],
    # . ConjugateTranspose[#] & /@ qmo["OrderedTensor"],
    projector /@ qmo["OrderedMatrix"]
]

QuantumMeasurementOperatorProp[qmo_, "Operators"] := If[qmo["POVMQ"],
    AssociationThread[Range[0, Length[qmo["Tensor"]] - 1], QuantumOperator[#, {Automatic, qmo["InputOrder"]}, QuantumBasis["Output" -> qmo["Basis"]["Input"]]] & /@ qmo["Tensor"]],
    AssociationThread[Eigenvalues[qmo["Matrix"]], QuantumOperator[projector @ #, {Automatic, qmo["InputOrder"]}, qmo["Basis"]] & /@ Eigenvectors[qmo["OrderedMatrix"]]]
]

QuantumMeasurementOperatorProp[qmo_, "SuperOperator"] := Module[{
    trace,
    traceQudits,
    tracedOperator,
    eigenvalues, eigenvectors, projectors,
    eigenBasis, outputBasis, inputBasis, operator
},
    trace = DeleteCases[qmo["FullInputOrder"], Alternatives @@ qmo["Target"]];
    traceQudits = trace - Min[qmo["FullInputOrder"]] + 1;
    If[
        ! qmo["ProjectionQ"],

        qmo["Operator"],

        tracedOperator = Chop @ Simplify @ QuantumPartialTrace[
            qmo,
            If[qmo["POVMQ"], {# + qmo["OutputQudits"] - qmo["InputQudits"], #} & /@ trace, trace]
        ];

        {eigenvalues, eigenvectors} = profile["Eigensystem"] @ Simplify @ tracedOperator["Eigensystem", "Sort" -> True];
        projectors = Simplify /@ Normal /@ tracedOperator["Projectors", "Sort" -> True];

        eigenBasis = QuditBasis[
            MapIndexed[
                Interpretation[Tooltip[Style[Subscript["\[ScriptCapitalE]", #1], Bold], StringTemplate["Eigenvalue ``"][First @ #2]], {#1, #2}] &,
                eigenvalues
            ],
            eigenvectors
        ];

        outputBasis = QuantumPartialTrace[qmo["Output"], Catenate @ Position[qmo["FullOutputOrder"], Alternatives @@ qmo["Target"]]];
        inputBasis = QuantumPartialTrace[qmo["Input"], Catenate @ Position[qmo["FullInputOrder"], Alternatives @@ qmo["Target"]]];

        (* construct *)
        operator = QuantumOperator[
            SparseArray @ Map[kroneckerProduct[IdentityMatrix[Times @@ qmo["InputDimensions"][[traceQudits]], SparseArray], #] &, projectors],
            QuantumBasis[
                "Output" -> QuantumTensorProduct[
                    eigenBasis,
                    QuditBasis[outputBasis["Dimensions"]],
                    QuditBasis[tracedOperator["OutputDimensions"]]
                ],
                "Input" -> QuantumTensorProduct[QuditBasis[inputBasis["Dimensions"]], QuditBasis[tracedOperator["InputDimensions"]]]
            ]
        ];

        (* change back basis *)
        operator = profile["basis change"] @ QuantumOperator[
            operator,
            {{0, 1}, qmo["InputOrder"]},
            QuantumBasis[
                "Output" -> QuantumTensorProduct[
                    eigenBasis,
                    outputBasis,
                    tracedOperator["Output"]
                ],
                "Input" -> QuantumTensorProduct[inputBasis, tracedOperator["Input"]],
                "Label" -> qmo["Label"],
                "ParameterSpec" -> qmo["ParameterSpec"]
            ]
        ];

        (* permute and set order *)
        Simplify @ QuantumOperator[
            operator[
                "PermuteOutput", InversePermutation @ FindPermutation[Prepend[1 + Join[traceQudits, qmo["Target"] - Min[qmo["InputOrder"]] + 1], 1]]
            ][
                "PermuteInput", InversePermutation @ FindPermutation[Join[traceQudits, qmo["Target"] - Min[qmo["InputOrder"]] + 1]]
            ],
            {Prepend[Sort @ qmo["OutputOrder"], 0], Sort @ qmo["InputOrder"]}
        ]
    ]
]

QuantumMeasurementOperatorProp[qmo_, "POVM"] := QuantumMeasurementOperator[qmo["SuperOperator"], qmo["Target"]]

QuantumMeasurementOperatorProp[qmo_, "QASM"] := StringRiffle[MapIndexed[StringTemplate["c[``] = measure q[``];"][First[#2] - 1, #1 - 1] &, qmo["Target"]], "\n"]


QuantumMeasurementOperatorProp[qmo_, "Shift", n : _Integer ? NonNegative : 1] :=
    QuantumMeasurementOperator[QuantumOperator[qmo]["Reorder", qmo["Order"] /. k_Integer ? Positive :> k + n], qmo["Target"] + n]

QuantumMeasurementOperatorProp[qmo_, "Bend", autoShift : _Integer ? Positive : Automatic] := With[{
    shift = Replace[autoShift, Automatic :> Max[qmo["Order"]]],
    target = qmo["Target"]
},
    If[ qmo["POVMQ"],
        QuantumMeasurementOperator[QuantumOperator[QuantumChannel[qmo]["Bend", shift]], Join[target, target - Min[target] + 1 + shift]],
        QuantumMeasurementOperator[QuantumOperator[qmo]["Bend", shift], Join[target, target - Min[target] + 1 + shift]]
    ]
]

QuantumMeasurementOperatorProp[qmo_, prop : "Conjugate" | "Dual" | "Unbend"] :=
    QuantumMeasurementOperator[qmo["SuperOperator"][prop], qmo["Target"]]


QuantumMeasurementOperatorProp[qmo_, "DiscardExtraQudits"] := QuantumOperator[
    Fold[
        #2[#1] &,
        qmo,
        (* TODO: figure out general scheme without relying on labels *)
        With[{pauli = FirstCase[qmo["Label"], "X" | "Y" | "Z" | "I", "I", All]}, Join[
            MapThread[QuantumOperator["Marginal"[#1], {#2}] &, {qmo["TargetBasis"]["Decompose"], qmo["TargetOrder"]}],
            MapThread[
                If[IntegerQ[#1], QuantumOperator["Measure"[pauli[#1]], {#2}], Nothing] &,
                {Sqrt @ qmo["Eigendimensions"], qmo["Eigenorder"]}
            ]
        ]]
    ],
    qmo["InputOrder"] -> qmo["TargetOrder"],
    "Label" -> "Measurement"[qmo["Label"]]
]


QuantumMeasurementOperatorProp[qmo_, "CircuitDiagram", opts___] :=
    QuantumCircuitOperator[qmo]["Diagram", opts]


(* operator properties *)

QuantumMeasurementOperatorProp[qmo_, prop : "Ordered" | "Sort" | "SortOutput" | "SortInput" | "Computational" | "Simplify" | "FullSimplify" | "Chop" | "ComplexExpand", args___] :=
    QuantumMeasurementOperator[qmo["QuantumOperator"][prop, args], qmo["Target"]]

QuantumMeasurementOperatorProp[qmo_, prop : "Dagger", args___] :=
    qmo["SuperOperator"][prop, args]

QuantumMeasurementOperatorProp[qmo_, prop : "Double", args___] :=
    QuantumMeasurementOperator[qmo["SuperOperator"][prop, args], qmo["Target"]]


QuantumMeasurementOperatorProp[qmo_, args : PatternSequence[prop_String, ___]] /;
    MemberQ[Intersection[qmo["Operator"]["Properties"], qmo["Properties"]], prop] := qmo["Operator"][args]

