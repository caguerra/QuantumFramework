Package["QuantumFramework`"]

PackageExport["QuantumState"]

PackageScope["QuantumStateQ"]


QuantumState::inState = "is invalid";

QuantumState::inBasis = "has invalid basis";

QuantumState::incompatible = "is incompatible with its basis";


QuantumStateQ[QuantumState[state_, basis_]] :=
    (stateQ[state] || (Message[QuantumState::inState]; False)) &&
    (QuantumBasisQ[basis] || (Message[QuantumState::inBasis]; False)) &&
    (Length[state] === basis["Dimension"] || (Message[QuantumState::incompatible]; False))

QuantumStateQ[___] := False


(* basis argument input *)

QuantumState[state_ ? stateQ, basisArgs___] /; !QuantumBasisQ[basisArgs] := Enclose @ Module[{
    basis, multiplicity
},
    basis = ConfirmBy[QuantumBasis[basisArgs], QuantumBasisQ];
    multiplicity = basisMultiplicity[Length[state], basis["Dimension"]];
    basis = ConfirmBy[QuantumBasis[basis, multiplicity], QuantumBasisQ];
    QuantumState[
        PadRight[state, Table[basis["Dimension"], TensorRank[state]]],
        basis
    ]
]


(* association input *)

QuantumState[state_ ? AssociationQ, basisArgs___] /; VectorQ[Values[state]] := Enclose @ Module[{
    basis = ConfirmBy[QuantumBasis[basisArgs], QuantumBasisQ], multiplicity},
    multiplicity = basisMultiplicity[Length[state], basis["Dimension"]];
    basis = ConfirmBy[QuantumBasis[basis, multiplicity], QuantumBasisQ];
    ConfirmAssert[ContainsOnly[QuditBasisName /@ Keys[state], basis["BasisElementNames"]], "Association keys and basis names don't match"];
    QuantumState[
        Values @ KeyMap[QuditBasisName, state][[Key /@ basis["BasisElementNames"]]] /. _Missing -> 0,
        basis
    ]
]


(* eigenvalues input *)

QuantumState["Eigenvalues" -> eigenvalues_ ? VectorQ, basisArgs___] := With[{
    basis = QuantumBasis[basisArgs]
},
    QuantumState[
        Total @ MapThread[#1 #2 &, {eigenvalues, basis["Projectors"]}],
        basis
    ] /; Length[eigenvalues] == basis["Dimension"]
]


(* expand basis *)

QuantumState[state_, args : Except[_ ? QuantumBasisQ]] := Enclose @ QuantumState[state, ConfirmBy[QuantumBasis[args], QuantumBasisQ]]

QuantumState[state_ ? stateQ, basis_ ? QuantumBasisQ] := QuantumState[
    state,
    QuantumTensorProduct[basis, QuantumBasis[Max[2, Length[state] - basis["Dimension"]]]]
] /; Length[state] > basis["Dimension"]


(* pad state *)

QuantumState[state_ ? stateQ, basis_ ? QuantumBasisQ] := QuantumState[
    PadRight[state, Table[basis["Dimension"], TensorRank[state]]],
    basis
] /; Length[state] < basis["Dimension"]


(* Mutation *)

QuantumState[qs_ ? QuantumStateQ, args : Except[_ ? QuantumBasisQ, _ ? nameQ]] := 
    Enclose @ QuantumState[qs, ConfirmBy[QuantumBasis[args], QuantumBasisQ]]

QuantumState[qs_ ? QuantumStateQ, args : Except[_ ? QuantumBasisQ]] :=
    Enclose @ QuantumState[qs, ConfirmBy[QuantumBasis[qs["Basis"], args], QuantumBasisQ]]


(* change of basis *)

QuantumState[qs_ ? QuantumStateQ, newBasis_ ? QuantumBasisQ] /; qs["BasisElementDimension"] === newBasis["BasisElementDimension"] := Switch[
    qs["StateType"],
    "Vector",
    QuantumState[
        Flatten[
            PseudoInverse[newBasis["OutputMatrix"]] . (qs["OutputMatrix"] . qs["StateMatrix"] . PseudoInverse[qs["InputMatrix"]]) . newBasis["InputMatrix"]
        ],
        newBasis
    ],
    "Matrix",
    QuantumState[
        PseudoInverse[newBasis["OutputMatrix"]] . (qs["OutputMatrix"] . qs["DensityMatrix"] . PseudoInverse[qs["InputMatrix"]]) . newBasis["InputMatrix"],
        newBasis
    ]
]


(* renew basis *)

QuantumState[qs_ ? QuantumStateQ] := qs["Computational"]

QuantumState[qs_ ? QuantumStateQ, args__] := With[{
    newBasis = QuantumBasis[qs["Basis"], args]},
    If[ qs["Basis"] === newBasis,
        qs,
        QuantumState[qs["State"], newBasis]
    ]
]


(* equality *)

QuantumState /: (qs1_QuantumState ? QuantumStateQ) == (qs2_QuantumState ? QuantumStateQ) :=
    qs1["Picture"] == qs2["Picture"] && qs1["MatrixRepresentation"] == qs2["MatrixRepresentation"]


(* composition *)

(qs1_QuantumState ? QuantumStateQ)[(qs2_QuantumState ? QuantumStateQ)] /; qs1["InputDimension"] == qs2["OutputDimension"] :=
    QuantumState[
        QuantumState[Flatten[qs1["MatrixRepresentation"] . qs2["MatrixRepresentation"]], QuantumBasis[{qs1["OutputDimension"], qs2["InputDimension"]}]],
        QuantumBasis[<|"Input" -> qs2["Input"], "Output" -> qs1["Output"], "Label" -> qs1["Label"] @* qs2["Label"]|>]
    ]
