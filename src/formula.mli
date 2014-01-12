(** Arithmetic formulas *)

open Apak
open ArkPervasives

exception Nonlinear

module type S = sig
  type t
  include Putil.Hashed.S with type t := t
  include Putil.OrderedMix with type t := t

  module T : Term.S

  (** {2 Formula constructors} *)

  (** True *)
  val top : t

  (** False *)
  val bottom : t

  val conj : t -> t -> t
  val disj : t -> t -> t

  (** [leqz t] is a formula representing [t <= 0]. *)
  val leqz : T.t -> t

  (** [eqz t] is a formula representing [t = 0]. *)
  val eqz : T.t -> t

  (** [ltz t] is a formula representing [t < 0]. *)
  val ltz : T.t -> t
  val atom : T.t atom -> t
  val eq : T.t -> T.t -> t
  val leq : T.t -> T.t -> t
  val geq : T.t -> T.t -> t
  val lt : T.t -> T.t -> t
  val gt : T.t -> T.t -> t
  val negate : t -> t

  val big_conj : t BatEnum.t -> t
  val big_disj : t BatEnum.t -> t

  (** {2 Formula deconstructors} *)

  (** [eval] is a fold for formulas.  More precisely, formulas are initial
      objects in the category of formula-algebras, and [eval alg] gives the
      (unique) morphism from the initial algebra to [alg] *)
  val eval : ('a, T.t atom) formula_algebra -> t -> 'a

  (** One-step unfolding of a formula *)
  val view : t -> (t, T.t atom) open_formula

  (** {2 Abstract domain operations} *)

  (** Covert an abstract value to a formula *)
  val of_abstract : 'a T.D.t -> t

  (** Convert a formula to a (possibly weaker) abstract value.  Optionally
      project the resulting abstract value onto a subset of the free variables
      in the formula (this is faster than abstracting and then projecting. *)
  val abstract : ?exists:(T.V.t -> bool) option ->
                 'a Apron.Manager.t ->
                 t ->
                 'a T.D.t

  (** Abstract post-condition of an assigment *)
  val abstract_assign : 'a Apron.Manager.t ->
                        'a T.D.t ->
                        T.V.t ->
                        T.t ->
                        'a T.D.t

  (** Abstract post-condition of an assumption *)
  val abstract_assume : 'a Apron.Manager.t -> 'a T.D.t -> t -> 'a T.D.t

  (** {2 Quantification} *)

  (** [exists p phi] existentially quantifies each variable in [phi] which
      does not satisfy the predicate [p]. The strategy used to eliminate
      quantifers is the one specified by [opt_qe_strategy]. *)
  val exists : (T.V.t -> bool) -> t -> t


  (** [exists vars phi] existentially quantifies each variable in [phi] which
      appears in the list [vars].  The strategy used to eliminate
      quantifiers is the one specified by [opt_qe_strategy] *)
  val exists_list : T.V.t list -> t -> t

  val opt_qe_strategy : ((T.V.t -> bool) -> t -> t) ref

  (** {3 Quantifier elimination strategies} *)

  (** Quantifier elimination algorithm based on lazy model enumeration, as
      described in David Monniaux: "Quantifier elimination by lazy model
      enumeration", CAV2010. *)
  val qe_lme : (T.V.t -> bool) -> t -> t

  (** Use Z3's built-in quantifier elimination algorithm *)
  val qe_z3 : (T.V.t -> bool) -> t -> t

  (** Over-approximate quantifier elimination.  Computes intervals for each
      variable to be quantified, and replaces occurrences of the variable
      with the appropriate bound.  *)
  val qe_cover : (T.V.t -> bool) -> t -> t

  (** {2 Misc operations} *)

  val of_smt : Smt.ast -> t
  val to_smt : t -> Smt.ast

  val implies : t -> t -> bool
  val equiv : t -> t -> bool

  (** Substitute every atom in a formula with another formula. *)
  val map : (T.t atom -> t) -> t -> t

  (** Apply a substitution *)
  val subst : (T.V.t -> T.t) -> t -> t

  (** Given an interpretation [m] and a formula [phi], [select_disjunct m phi]
      finds a clause in the DNF of [phi] such that [m] is a model of that
      clause (or return [None] if no such clause exists). *)
  val select_disjunct : (T.V.t -> QQ.t) -> t -> t option

  val symbolic_bounds : (T.V.t -> bool) -> t -> T.t -> (pred * T.t) list

  (** Over-approximate an arbitrary formula by a linear arithmetic formula *)
  val linearize : (unit -> T.V.t) -> t -> t

  val symbolic_abstract : (T.t list) -> t -> (QQ.t option * QQ.t option) list
  val disj_optimize : (T.t list) -> t -> (QQ.t option * QQ.t option) list list

  val dnf_size : t -> int
  val nb_atoms : t -> int
  val size : t -> int

  val log_stats : unit -> unit

  module Syntax : sig
    val ( && ) : t -> t -> t
    val ( || ) : t -> t -> t
    val ( == ) : T.t -> T.t -> t
    val ( < ) : T.t -> T.t -> t
    val ( > ) : T.t -> T.t -> t
    val ( <= ) : T.t -> T.t -> t
    val ( >= ) : T.t -> T.t -> t
  end
end

module Make (T : Term.S) : S with module T = T
module MakeEq (F : S) : sig
  module AMap : BatMap.S with type key = F.T.V.t affine
  (** [extract_equalities phi vars] computes a basis for the smallest linear
      manifold which contains [phi] and is defined over the variables
      [vars]. *)
  val extract_equalities : F.t -> F.T.V.t list -> F.T.Linterm.t list
end
