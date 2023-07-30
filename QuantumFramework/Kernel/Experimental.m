Package["Wolfram`QuantumFramework`"]

PackageScope["DecomposedQuantumStateProbabilities"]
PackageScope["QuantumBeamSearch"]
PackageScope["QuantumDiagramProcess"]

PackageExport["QuantumCircuitMultiwayGraph"]
PackageExport["QuantumMPS"]
PackageExport["QuantumMPO"]



DecomposedQuantumStateProbabilities[states : {{__QuantumState}..}] :=
	Normalize[Abs[Total[Flatten[Outer[Times, Sequence @@ #, 1], Length[#]] & /@ Map[#["Computational"]["StateVector"] &, states, {2}]]] ^ 2, Total]

DecomposedQuantumStateProbabilities[states : {(_ -> {__QuantumState})..}] :=
	Normalize[Abs[Total[states[[All, 1]] (Flatten[Outer[Times, Sequence @@ #, 1], Length[#]] & /@ Map[#["Computational"]["StateVector"] &, states[[All, 2]], {2}])]] ^ 2, Total]

BeamBranch[prob_ -> states_, op_] := With[{
	decompose = op["State"][
		QuantumTensorProduct[states[[op["InputOrder"]]]]
	]["DecomposeWithProbabilities"]
},
	prob #1 -> ReplacePart[states, Thread[op["InputOrder"] -> #2]] & @@@ decompose
]


Options[QuantumBeamSearch] = {"Width" -> 8, "Deterministic" -> False, "Shots" -> 1};

QuantumBeamSearch[states_List, ops_List, OptionsPattern[]] := Module[{
	width = OptionValue["Width"],
	random = !TrueQ[OptionValue["Deterministic"]],
	shots = OptionValue["Shots"]
},
	Normalize[#, Total] & @ Total @ Table[
		DecomposedQuantumStateProbabilities @ Fold[
			{beam, op} |-> SubsetMap[Normalize[#, Total] &, {All, 1}] @
				With[{candidates = Catenate[BeamBranch[#, op] & /@ beam]},
					If[ random,
						RandomSample[candidates[[All, 1]] -> candidates, UpTo[width]],
						TakeLargestBy[candidates, First, UpTo[width]]
					]
				],
			{1 -> states},
			N @ ops
		],
		shots
	]
]


operatorApply[op_ ? QuantumOperatorQ, states : {_ ? QuantumStateQ ..}] := Enclose @ With[{
	inputOrder = op["FullInputOrder"],
	outputOrder = op["FullOutputOrder"]
},
	ConfirmAssert[1 <= Min[inputOrder] <= Max[inputOrder] <= Length[states]];
	ConfirmAssert[1 <= Min[outputOrder] <= Max[outputOrder] <= Length[states]];
	Map[
		ReplacePart[states, Thread[outputOrder -> #]] &,
		op["State"][QuantumTensorProduct @@ states[[inputOrder]]]["Decompose"]
	]
]

QuantumCircuitMultiwayGraph[circuit_, initStates : Except[OptionsPattern[]] : Automatic, opts : OptionsPattern[]] := Enclose @ Block[{
	index = 0
},
	VertexReplace[
		ResourceFunction["FoldGraph"][
			List /* Replace[{{pos_, states_}, op_} :> (
				index++;
				MapIndexed[
					With[{newPos = Join[pos, #2]},
						Labeled[{newPos, #1}, <|
							"Destroyed" -> op["FullInputOrder"],
							"Created" -> op["FullOutputOrder"],
							"Step" -> Length[newPos],
							"TreePosition" -> newPos,
							"Index" -> index,
							"Operator" -> op
						|>]
					] &,
					Confirm @ operatorApply[op, states]
				]
			)],
			{{{}, Replace[initStates, Automatic -> Table[QuantumState["0"], circuit["Arity"]]]}},
			#["Sort"] & /@ circuit["Flatten"]["Operators"],
			opts,
			GraphLayout -> {"LayeredDigraphEmbedding", "Orientation" -> Left}
		],
		{_, states_} :> states
	]
]



DiagramProcess := DiagramProcess = ResourceFunction["https://www.wolframcloud.com/obj/murzin.nikolay/DeployedResources/Function/DiagramProcess"]

QuantumDiagramProcess[qco_QuantumCircuitOperator] := With[{
    ops = qco["Operators"], net = qco["TensorNetwork", "PrependInitial" -> False], n = qco["Gates"]
},
    With[{
        map = GroupBy[EdgeTags[net], #[[2]] &, #[[1, 1]] &],
        freeIndices = TensorNetworkFreeIndices[net]
    },
        DiagramProcess[
            Subsuperscript[
                With[{mat = ops[[#]]["Computational"]["Tensor"]}, Labeled[Part[mat, ##] &, ops[[#]]["Label"]]],
                Sequence @@ Reverse @ Replace[
                    MapAt[ReplaceAll[map], TakeDrop[HoldForm /@ AnnotationValue[{net, #}, "Index"], ops[[#]]["OutputQudits"]], 2],
                    With[{
                        outs = Alternatives @@ Cases[freeIndices, _Superscript],
                        ins = Alternatives @@ Cases[freeIndices, _Subscript]
                    },
                        {in : HoldForm[ins] :> Overscript[in, ˘], out : HoldForm[outs] :> Overscript[out, \[DownBreve]]}
                    ],
                    {2}
                ]
            ] & /@ Range[n]
        ]
    ]
]


Options[QuantumMPS] = {"Ordered" -> False, "Sides" -> True}

QuantumMPS[qs_ ? QuantumStateQ, m : _Integer | Infinity : Infinity, OptionsPattern[]] := Block[{
	decompose = If[VectorQ[#[[All, 1]], NumericQ], TakeLargestBy[#, First, UpTo[m]], #] & @ qs["DecomposeWithAmplitudes", qs["Dimensions"]],
	dimensions = qs["Dimensions"],
	proba, n, rowVector, colVector, matrices, result
},
	n = Length[decompose];
	proba = Keys[decompose];

	matrices = If[n > 1,
		colVector = QuantumOperator[{Table[{1}, n]}, {{0}, {}}, QuantumBasis[{n}, {}, "Label" -> TraditionalForm[Bra[{" "}]]]];
		rowVector = QuantumOperator[{proba}, {{}, {0}}, QuantumBasis[{}, {n}, "Label" -> TraditionalForm[Ket[{" "}]]]];
		matrices = MapIndexed[
			QuantumOperator[
				Transpose[
					ReplacePart[ConstantArray[Table[0, #1[[2]]], {n, n}], Thread[{#, #} & /@ Range[n] -> #1[[1]], List, 2]],
					2 <-> 3
				],
				If[#2[[1]] <= qs["OutputQudits"], {Prepend[#2, 0], {0}}, {{0}, Append[#2, 0]}],
				QuantumBasis[{n, #1[[2]]}, {n}]
			] &,
			Thread[{Transpose @ Map[#["Computational"]["StateVector"] &, Values[decompose], {2}], dimensions}]
		],

		colVector = Nothing;
		rowVector = QuantumOperator[{proba}, {{}, {}}, QuantumBasis[{}, {}, "Label" -> TraditionalForm[First[proba]]]];
		matrices = MapIndexed[
			QuantumOperator[{{#1[[1]]}}, {#2, {}}, QuantumBasis[{#1[[2]]}, {}]] &,
			Thread[{Transpose @ Map[#["Computational"]["StateVector"] &, Values[decompose], {2}], dimensions}]
		]
	];
	result = If[TrueQ[OptionValue["Sides"]],
		QuantumCircuitOperator[{colVector, Splice @ matrices, rowVector}],
		QuantumCircuitOperator[MapAt[rowVector, -1] @ MapAt[If[colVector === Nothing, #, #[colVector]] &, 1] @ matrices]
	];
	If[	TrueQ[OptionValue["Ordered"]],
		result = Reverse[MapIndexed[{"I", #1} -> #2 -> qs["OutputQudits"] + #2 &, qs["InputDimensions"]]] /* result
	];
	QuantumCircuitOperator[result, "MPS"]
]

QuantumMPS[qo_ ? QuantumOperatorQ, m : _Integer | Infinity : Infinity, opts : OptionsPattern[]] :=
	With[{range = Range[Length[qo["InputOrder"]]]},
		{{"Permutation", qo["InputDimensions"], range} -> qo["InputOrder"] -> range + Length[qo["OutputOrder"]]}
	] /*
	QuantumMPS[qo["State"], m, "Ordered" -> False, opts] /*
	With[{range = Range[Length[qo["OutputOrder"]]]},
		{{"Permutation", qo["OutputDimensions"], range} -> range -> qo["OutputOrder"]}
	]


Options[QuantumMPO] = {"Ordered" -> True}

QuantumMPO[qo_QuantumOperator, m : _Integer | Infinity : Infinity, OptionsPattern[]] := Block[{
	mps = QuantumMPS[qo["ReverseInput"]["State"], m, "Sides" -> False],
	top, bot, split,
	result
},
	{top, bot} = TakeDrop[mps["Operators"], qo["OutputQudits"]];
	split = Length[top] - Length[bot];
	bot = #["Transpose", {{0, -1}, {-1, 0}}] & /@ Reverse[bot];
	result = QuantumCircuitOperator[
		If[ split > 0,
			Join[top[[;; split]], MapThread[Construct, {top[[split + 1 ;;]], bot}]],
			Join[bot[[;; - split]], MapThread[Construct, {top, bot[[- split + 1 ;;]]}]]
		] //
		MapAt[QuantumOperator[{"Cap", #["OutputDimensions"][[1]]}, {-1, 0}][#] &, -1] //
		MapAt[
			If[
				ContainsAll[#["OutputOrder"], {-1 ,0}],
				QuantumOperator[{"Uncurry", Replace[{-1, 0}, #["OutputOrderDimensions"], {1}]}, {-1, 0} -> {0}][#],
				QuantumOperator[#["State"], {#["OutputOrder"] /. -1 -> 0, #["InputOrder"]}]
			] &,
			{;; -2}
		] //
		MapAt[
			If[
				ContainsAll[#["InputOrder"], {-1 ,0}],
				#[QuantumOperator[{"Curry", Replace[{-1, 0}, #["InputOrderDimensions"], {1}]}, {0} -> {-1, 0}]],
				QuantumOperator[#["State"], {#["OutputOrder"], #["InputOrder"] /. -1 -> 0}]
			] &,
		 	{2 ;;}
		] //
		Map[QuantumOperator[
			#["State"],
			{#["OutputOrder"], Replace[#["InputOrder"], i_ /; i > qo["OutputQudits"] :> qo["Qudits"] - i + Max[split, 0] + 1, {1}]},
			"Label" -> None] &
		]
	];
	If[	TrueQ[OptionValue["Ordered"]],
		result =
			{{"Permutation", qo["InputDimensions"]} -> qo["InputOrder"] -> Reverse[Range[Length[qo["InputOrder"]]] + Max[split, 0]]} /*
			result /*
			{{"Permutation", qo["OutputDimensions"]} -> Range[Length[qo["OutputOrder"]]] -> qo["OutputOrder"]}
	];
	QuantumCircuitOperator[result, "MPO"]
]

