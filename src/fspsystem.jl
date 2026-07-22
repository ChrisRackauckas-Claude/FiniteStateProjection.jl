"""
    FSPSystem(rs::Catalyst.ReactionSystem, [ih]; combinatoric_ratelaw = true)

Represent a Catalyst reaction system as a finite state projection (FSP) system.
`FSPSystem` stores the reaction system, an index handler describing the state-array
layout, and generated rate functions used to construct ODE and steady-state problems.

# Arguments
- `rs`: Catalyst reaction system without subsystems.
- `ih`: Index handler for the FSP state array. By default,
  `DefaultIndexHandler` uses Catalyst's species order.
- `combinatoric_ratelaw`: Whether to use combinatoric jump rate laws.

# Examples
```julia
using Catalyst

rn = @reaction_network begin
    birth, 0 --> A
    death, A --> 0
end
fsp = FSPSystem(rn)
```
"""
struct FSPSystem{IHT <: AbstractIndexHandler, RT}
    rs::ReactionSystem
    ih::IHT
    rfs::RT
end

function FSPSystem(
        rs::ReactionSystem,
        ih::AbstractIndexHandler = DefaultIndexHandler{length(species(rs))}();
        combinatoric_ratelaw::Bool = true
    )
    isempty(get_systems(rs)) ||
        error("Supported Catalyst models can not contain subsystems. Use `ModelingToolkitBase.flatten(rs)` to generate a single system with no subsystems from your Catalyst model.")
    any(eq -> !(eq isa Reaction), equations(rs)) &&
        error("Catalyst models that include constraint ODEs or algebraic equations are not supported.")

    rfs = create_ratefuncs(rs, ih; combinatoric_ratelaw = combinatoric_ratelaw)
    return FSPSystem(rs, ih, rfs)
end

function FSPSystem(rs::ReactionSystem, order::AbstractVector{Symbol}; kwargs...)
    return FSPSystem(rs, PermutingIndexHandler(rs, order); kwargs...)
end

"""
    build_ratefuncs(rs, ih; state_sym::Symbol, combinatoric_ratelaw::Bool)::Vector

Return the rate functions converted to Julia expressions in the state variable
`state_sym`. Abundances of the species are computed using `getsubstitutions`.

See also: [`getsubstitutions`](@ref), [`build_rhs`](@ref)
"""
function build_ratefuncs(
        rs::ReactionSystem, ih::AbstractIndexHandler;
        state_sym::Symbol, combinatoric_ratelaw::Bool = true
    )
    substitutions = getsubstitutions(ih, rs, state_sym = state_sym)

    return map(reactions(rs)) do reac
        jrl = jumpratelaw(reac; combinatoric_ratelaw)
        jrl_s = substitute(jrl, substitutions)
        toexpr(jrl_s)
    end
end

function create_ratefuncs(rs::ReactionSystem, ih::AbstractIndexHandler; combinatoric_ratelaw::Bool = true)
    paramsyms = Symbol.(parameters(rs))

    return tuple(
        map(
            ex -> compile_ratefunc(ex, paramsyms),
            build_ratefuncs(rs, ih; state_sym = :idx_in, combinatoric_ratelaw)
        )...
    )
end

function compile_ratefunc(ex_rf, params)
    ex = _flatten(:((idx_in, t, $(params...)) -> $(ex_rf)))
    return @RuntimeGeneratedFunction(ex)
end

_parameter_symbol(key::Symbol) = key
_parameter_symbol(key) = Symbol(value(key))

function pmap_to_p(sys::FSPSystem, pmap)
    pmap isa SciMLBase.NullParameters && return pmap
    values_by_parameter = Dict(_parameter_symbol(k) => v for (k, v) in pmap)
    return [values_by_parameter[p] for p in Symbol.(parameters(sys.rs))]
end
