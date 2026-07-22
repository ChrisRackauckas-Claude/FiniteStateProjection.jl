module FiniteStateProjection

using Catalyst: Reaction, ReactionSystem, jumpratelaw, netstoichmat, numspecies, parameters,
    reactions, species
using ModelingToolkitBase: equations, get_systems
import RuntimeGeneratedFunctions
using RuntimeGeneratedFunctions: @RuntimeGeneratedFunction
import SciMLBase
using SciMLBase: ODEFunction, ODEProblem, SteadyStateProblem
import SparseArrays
using SparseArrays: sparse
using SymbolicIndexingInterface: getname
using Symbolics: @variables, value
using SymbolicUtils: scalarize, substitute
using SymbolicUtils.Code: toexpr

import Base: LinearIndices, vec

RuntimeGeneratedFunctions.init(@__MODULE__)

export FSPSystem, DefaultIndexHandler, SteadyState

_unresolve1(x) = x
@static if VERSION >= v"1.12-"
    _unresolve1(f::Function) = nameof(f)
else
    _unresolve1(f::Function) = methods(f).mt.name
end

_prewalk(f, x) = _prewalk_children(f(x), f)
_prewalk_children(x, f) = x
_prewalk_children(x::Expr, f) = Expr(x.head, map(arg -> _prewalk(f, arg), x.args)...)

function _striplines(ex)
    ex isa Expr || return ex
    args = (arg for arg in ex.args if !(arg isa LineNumberNode))
    return Expr(ex.head, _striplines.(args)...)
end

function _flatten(ex)
    ex isa Expr || return ex
    args = _flatten.(ex.args)
    ex.head === :block || return Expr(ex.head, args...)

    flattened = Any[]
    for arg in args
        arg isa Expr && arg.head === :block ? append!(flattened, arg.args) : push!(flattened, arg)
    end
    return length(flattened) == 1 ? only(flattened) : Expr(:block, flattened...)
end

_unresolve(ex) = _prewalk(_unresolve1, ex)
function _prettify(ex; lines = false)
    ex = lines ? ex : _striplines(ex)
    return _unresolve(_flatten(ex))
end

abstract type AbstractIndexHandler end

include("fspsystem.jl")
include("indexhandlers.jl")
include("build_rhs.jl")
include("build_rhs_ss.jl")
include("matrix.jl")

end
