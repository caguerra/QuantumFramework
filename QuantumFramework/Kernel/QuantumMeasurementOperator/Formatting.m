Package["Wolfram`QuantumFramework`"]



QuantumMeasurementOperator /: MakeBoxes[qmo_QuantumMeasurementOperator /; QuantumMeasurementOperatorQ[Unevaluated @ qmo], format_] := With[{
    icon = If[
        qmo["Dimension"] < 2 ^ 9,
        MatrixPlot[
            Map[Replace[x_ ? (Not @* NumericQ) :> BlockRandom[RandomColor[], RandomSeeding -> Hash[x]]],
                If[ qmo["POVMQ"],
                    ArrayReshape[
                        Nest[Mean, qmo["Ordered"]["TensorRepresentation"], qmo["Targets"]],
                        qmo["MatrixNameDimensions"] / {Times @@ Take[qmo["Dimensions"], qmo["Targets"]], 1}
                    ],
                    qmo["Ordered"]["MatrixRepresentation"]
                ],
                {2}
            ],
            ImageSize -> Dynamic @ {Automatic, 3.5 CurrentValue["FontCapHeight"] / AbsoluteCurrentValue[Magnification]},
            Frame -> False,
            FrameTicks -> None
        ],
        RawBoxes @ $SparseArrayBox
    ]
},
    BoxForm`ArrangeSummaryBox["QuantumMeasurementOperator", qmo,
        icon, {
            {
                BoxForm`SummaryItem[{"Measurement Type: ", qmo["Type"]}],
                BoxForm`SummaryItem[{"Target: ", qmo["Target"]}]
            },
            {
                BoxForm`SummaryItem[{"Dimension: ", Row[{qmo["InputDimension"], "\[RightArrow]", qmo["OutputDimension"]}]}],
                BoxForm`SummaryItem[{"Qudits: ", Row[{qmo["InputQudits"], "\[RightArrow]", qmo["OutputQudits"]}]}]
            }
        },
        {
            {
                BoxForm`SummaryItem[{"Hermitian: ", qmo["HermitianQ"]}],
                BoxForm`SummaryItem[{"Order: ", Row[{qmo["InputOrder"], "\[RightArrow]", qmo["OutputOrder"]}]}]
            },
            {
                BoxForm`SummaryItem[{"Unitary: ", qmo["UnitaryQ"]}],
                BoxForm`SummaryItem[{"Dimensions: ",
                    Row[{qmo["InputDimensions"], "\[RightArrow]", qmo["OutputDimensions"]}]}
                ]
            }
        },
        format,
        "Interpretable" -> Automatic
    ]
]

