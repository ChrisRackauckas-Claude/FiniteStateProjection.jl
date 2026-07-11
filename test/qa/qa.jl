using SciMLTesting, FiniteStateProjection, Test
using JET

run_qa(
    FiniteStateProjection;
    explicit_imports = true,
    jet_kwargs = (; target_defined_modules = true),
    # Pre-existing Aqua findings tracked in SciML/FiniteStateProjection.jl#60.
    aqua_broken = (
        :ambiguities,        # pairedindices DefaultIndexHandler{0} overlap (indexhandlers.jl 89/97/116)
        :unbound_args,       # pairedindices unbound type params (indexhandlers.jl 97/116)
        :undefined_exports,  # @reexport using Catalyst re-exports names absent from loaded deps
    ),
    # JET reports 3 issues (NaiveIndexHandler @deprecate kwcall; NullParameters used
    # but not imported in build_rhs.jl/build_rhs_ss.jl). Tracked in #60.
    jet_broken = true,
    ei_kwargs = (;
        # Names re-exported by a non-owner dependency (resolve to the owner as base
        # libraries adopt public/owner declarations).
        all_qualified_accesses_via_owners = (;
            ignore = (
                :get_systems,  # owner ModelingToolkit, accessed via Catalyst
                :scalarize,    # owner Symbolics, accessed via ModelingToolkit
                :value,        # owner Symbolics, accessed via ModelingToolkit
            ),
        ),
        # These names are still non-public in their resolvable owners, or are
        # re-exported from a non-owner. Drop each ignore as its owner ships a public
        # declaration that FiniteStateProjection can actually resolve.
        all_qualified_accesses_are_public = (;
            ignore = (
                :_symbol_to_var,   # Catalyst (non-public)
                :get_systems,      # Catalyst (owner ModelingToolkit; still non-public)
                :symmap_to_varmap, # Catalyst (non-public)
                :alias_gensyms,    # MacroTools (non-public)
                :flatten,          # MacroTools (non-public)
                :prewalk,          # MacroTools (non-public)
                :resyntax,         # MacroTools (non-public)
                :striplines,       # MacroTools (non-public)
                :scalarize,        # ModelingToolkit (owner Symbolics; still non-public)
                :value,            # ModelingToolkit (owner Symbolics; still non-public)
                :varmap_to_vars,   # ModelingToolkit (non-public)
                :NullParameters,   # SciMLBase (public in 3.30+, but Catalyst 15 pins 2.153.1 where it is not)
            ),
        ),
    ),
    api_docs_kwargs = (;
        ignore = (
            :SymbolicUtils,
            # Re-exported symbolic/Catalyst names that are not documented by
            # FiniteStateProjection itself.
            Symbol("@brownian"), Symbol("@mtkbuild"), Symbol("@species"),
            Symbol("@symbolic_wrap"), Symbol("@transport_reaction"), Symbol("@wrapped"),
            :AbstractCollocation, :CartesianGrid, :DiscreteSystem, :DynamicOptSolution,
            :ImplicitDiscreteSystem, :NaiveIndexHandler, :ODESystem, :RuleSet,
            :TransportReaction, :default_t, :default_time_deriv, :get_canonical_expr,
            :hc_steady_states, :independent_variable, :infimum, :irreducibles,
            :is_derivative, :iscall, :istree, :make_si_ode, :maybe_zeros,
            :plot_complexes, :plot_network, :setnominal, :solve_for,
            :stronglinkageclasses, :structural_simplify, :supremum,
            :terminallinkageclasses,
        ),
    ),
    # Heavy `@reexport using Catalyst` plus the symbolic stack make ~23 names
    # implicit; making them all explicit is a risky mass refactor. Tracked in #60.
    ei_broken = (:no_implicit_imports,),
)
