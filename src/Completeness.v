(* begin hide *)
Require Import Brenner.ResourceDependency.
Require Import Brenner.DependencyState.
Require Import Brenner.DependencyStateImpl.
Require Import Brenner.Semantics.
Require Import Brenner.Vars.
Require Import Brenner.Syntax.

Require Aniceto.Graphs.Graph.
Require Import Aniceto.Graphs.FGraph.
Require Import Aniceto.Map.
Require Import Aniceto.Set.

Require Import Coq.Lists.SetoidList.
Require Import Coq.Bool.Bool.
(* end hide *)

(** * Completeness *)

(**
  The property of completeness entails the absense of false negatives,
  that is for any deadlocked state [s] we can exhibit a cycle in the
  WFG of [s].
  The proof is divided into two steps.
  First, we consider totally deadlocked states [s], in which we observe that each
  task is a vertex in the WFG of [s] with an outgoing edge.
  There is a cycle in any finite graph whose vertices have at least an outgoing edge,
  so totally deadlock states have a cycle.
  Second, we show the WFG of a totally deadlocked state is a subgraph
  of the WFG of the relative deadlocked state, thus we can conclude
  our proof.
*)

(** ** Building the WFG *)

(**
  Let [WFG_of s g] read as the finite WFG [g] of state [s].
  Here, we define a finite graph as a sequence of edges, which pair
  vertices of type [tid] (the set of vertices can be obtained by ranging over
  all arcs).
*)

Definition WFG_of s g := 
  forall (e:(tid * tid)), List.In e g <-> TEdge s e.

(**
  There exists a finite WFG for any state [s], the proof is outside the scope
  of this document.
  *)

Theorem wfg_of_total:
  forall s:state, exists g, WFG_of s g.
Proof.
  intros.
  unfold WFG_of.
  destruct (deps_of_total s) as (d, Hd).
  destruct (DependencyState.wfg_of_total d) as (g, Hwfg).
  exists g.
  destruct e as (t, t').
  split.
  - intros.
    apply Hwfg in H.
    destruct H as (r, (Hw, Hi)).
    rewrite (wedge_eq_wait_on Hd) in Hw.
    rewrite (iedge_eq_impeded_by Hd) in Hi.
    apply tedge_spec.
    exists r; intuition.
  - intros.
    apply Hwfg.
    unfold WFGEdge.
    inversion H.
    subst; simpl in *.
    exists b.
    rewrite (wedge_eq_wait_on Hd).
    rewrite (iedge_eq_impeded_by Hd).
    intuition.
Qed.

(** * Completeness for totally deadlocked states *)

(**
  The proof for completeness in totally deadlocked states is driven by a simple observation:
  for every vertex in the WFG of a totally deadlocked state [s] there is at least one
  outgoing edge.
  Given that there is  a cycle in any finite graph in which every node has at least
  an outgoing edge, then the WFG of [s] has a cycle. 
  For the rest of this sub-section, let [s] be a state that is totally deadlocked,
  and let [g] a finite WFG such that [WFG_of s g] holds.
*)

(* begin hide *)

Section TOTALLY_COMPLETE.
Variable s:state.
Variable w:t_walk.
Variable g: list (tid * tid) % type.
Variable wfg_spec: WFG_of s g.
Variable s_deadlocked: TotallyDeadlocked s.

(** Any edge in a graph [wfg] is a [TEdge] (i.e., a WFG edge). *)

Lemma totally_deadlocked_edge: forall e, Edge g e -> TEdge s e.
Proof.
  intros.
  unfold Edge in *.
  apply wfg_spec.
  assumption.
Qed.

(* end hide *)

(** printing nil $\emptyset$ **)

(** We have that if task [t] is blocked on event [e], then
    there exists a task [t'] such that event [e]
    impeded_by task [t'], by unfolding the definition of [TotallyDeadlocked]. *)

Lemma totally_deadlocked_impeded_by:
  forall t e, WaitOn s t e -> exists t', ImpededBy s e t'.
Proof.
  intros.
  unfold TotallyDeadlocked in s_deadlocked.
  destruct s_deadlocked as (_, (Himpeded_by, _)).
  apply Himpeded_by in H.
  assumption.
Qed.

(**
    We also know that if [t] is blocked on [e] and [e] impeded_by [t'],
    then [(t,t')] is an edge in the WFG associated with [s], hence [(t,t')] is
    in graph [g]. *)

Lemma totally_deadlocked_blocked_odgree_1:
  forall t e, WaitOn s t e -> exists t', Edge g (t, t').
Proof.
  intros.
  destruct (totally_deadlocked_impeded_by _ _ H) as (t', Hi).
  unfold Edge.
  exists t'.
  apply wfg_spec.
  rewrite tedge_spec with (s:=s).
  exists e.
  intuition.
Qed.

(** Therefore, it follows that if [t] is blocked, then [t] has
    an outgoing edge in [g]. *)

Lemma totally_deadlocked_blocked_odgree:
  forall t e, WaitOn s t e -> HasOutgoing g t.
Proof.
  intros.
  apply totally_deadlocked_blocked_odgree_1 in H.
  destruct H as (t', H).
  apply has_outgoing_def with (v':=t').
  assumption.
Qed.


(** It is easy to see that any task [t] in [g] is blocked. *)

Lemma totally_deadlocked_vertex_blocked:
  forall t, Graph.In (Edge g) t -> exists e, WaitOn s t e.
Proof.
  intros.
  destruct H as (e, (He, Hin)).
  unfold Edge in *.
  unfold WFG_of in *.
  rewrite wfg_spec in *.
  destruct e as (t1, t2).
  rewrite tedge_spec in He.
  destruct He as (e, (Hwf, Himp)).
  inversion Hin.
  - subst; simpl in *.
    exists e; auto.
  - subst; simpl in *.
    apply impeded_by_in_tasks in Himp.
    apply s_deadlocked in Himp.
    assumption.
Qed.

(**
    Since any [t] in [g] is blocked, then by Lemma [totally_deadlocked_blocked_odgree]
    any task [t] in [g] has an outgoing edge. *)

Lemma totally_deadlocked_all_outgoing: AllOutgoing g.
Proof.
  intros.
  unfold AllOutgoing.
  unfold Graph.Forall.
  intros.
  apply totally_deadlocked_vertex_blocked in H; repeat auto.
  destruct H as (e, Hb).
  apply totally_deadlocked_blocked_odgree with (e:=e); repeat auto.
Qed.

(** From definition [TotallyDeadlocked] there exists
    a task [t] and this task is blocked,
    thus from [totally_deadlocked_blocked_odgree]
    task [t] has an outgoing edge, and therefore [g] is nonempty. *)

Lemma totally_deadlocked_nonempty: g <> nil.
Proof.
  intros.
  destruct s_deadlocked as (HallWait, (_, (t, Hin))).
  destruct (HallWait _ Hin) as (e, Hwaiton).
  intuition.
  apply totally_deadlocked_blocked_odgree with (e:=e) in Hwaiton; repeat auto.
  subst.
  inversion Hwaiton; subst.
  inversion H.
Qed.

(** As graph [g] is nonempty and given that all vertices in [g] have
    outgoing edges, then from Lemma [all_pos_odegree_impl_cycle] graph [g] has
    a cycle. *)

Theorem totally_deadlock_has_cycle: exists c, Graph.Cycle (Edge g) c.
Proof.
  intros.
  apply all_pos_odegree_impl_cycle.
  - apply TID.eq_dec.
  - apply totally_deadlocked_nonempty.
  - apply totally_deadlocked_all_outgoing.
Qed.

(* begin hide *)
End TOTALLY_COMPLETE.
(* end hide *)

(** * Completeness for deadlocked states *)

(* begin hide *)

Section DeadlockedStates.
Variable s : state.
Variable deadlocked_tasks : Map_TID.t prog.
Variable other_tasks: Map_TID.t prog.
Variable partition_holds: Map_TID_Props.Partition (get_tasks s) deadlocked_tasks other_tasks.

(**
Let [s] be a state and task maps $T_d$ and $T_o$ be such that $gettasks\ s = T_o \uplus T_d$.
Furthermore, let [ds] be the totally deadlocked state obtained from [s]. *)

Let ds := (get_phasers s, deadlocked_tasks).

(** The wait-on, regsitered, and impeded_by relations hold from a deadlocked to the totally
    deadlocked state, using the definition of [Partition]. *)
(* begin hide *)
Let wait_on_conv:
  forall t r,
  WaitOn ds t r ->
  WaitOn s t r.
Proof.
  intros.
  unfold WaitOn in *.
  destruct H as (p, (?, ?)).
  exists p.
  intuition.
  unfold Map_TID_Props.Partition in *.
  destruct partition_holds as (_, Hp).
  rewrite Hp.
  intuition.
Qed.

(**
  We have that [t] is registered in [r] by unfolding
  the definition of [Registered] and using Lemma [wait_on_conv].
*)

Let partition_in:
  forall {elt:Type} m m1 m2 k,
  Map_TID_Props.Partition (elt:=elt) m m1 m2 ->
  Map_TID.In k m1 ->
  Map_TID.In k m.
Proof.
  intros.
  unfold Map_TID_Props.Partition in *.
  destruct H as (H, Hx).
  apply Map_TID_Extra.in_to_mapsto in H0.
  destruct H0 as (?, Hm).
  apply Map_TID_Extra.mapsto_to_in with (x).
  rewrite Hx.
  auto.
Qed.

Let registered_conv:
  forall t r,
  Registered ds t r ->
  Registered s t r.
Proof.
  intros.
  unfold Registered in *.
  destruct H as (ph, (Hmp,(Hmt,Hi))); exists ph.
  intuition.
  eauto.
Qed.

Let impeded_by_conv:
  forall r t,
  ImpededBy ds r t ->
  ImpededBy s r t.
Proof.
  intros.
  unfold ImpededBy in *.
  destruct H as ((t',?), (r', (?, ?))).
  split.
  - exists t'.
    auto.
  - exists r'.
    intuition.
Qed.

Lemma tedge_conv: 
  forall e,
  TEdge ds e ->
  TEdge s e.
Proof.
  intros.
  inversion H; clear H; subst.
  eauto using Bipartite.aa, wait_on_conv, impeded_by_conv.
Qed.

End DeadlockedStates.

(* end hide *)

(**
  Let states [s] and [s'] be such that [s' := (get_phasers s, m)]
  and [m] and [m'] are two disjoint task maps of [get_tasks s].
  It is easy to show that an edge in the WFG of [s'] is also in the WFG of [s].
  The proof uses the standard library's properties about [Partition]
  and by trivial unfolding of the definitions [WaitOn] and [ImpededBy].

*)

Lemma tedge_partition:
  forall s m m',
  let s' := (get_phasers s, m) in
  Map_TID_Props.Partition (get_tasks s) m m' ->
  forall e,
  TEdge s' e -> TEdge s e.
Proof.
  eauto using tedge_conv.
Qed.

(* begin hide *)

Section Bootstrap.
Variable s:state.
Variable g: list (tid * tid).
Variable wfg_spec: WFG_of s g.
Variable is_deadlocked : Deadlocked s.

(* end hide *)

(** 
  Now, let [s] be a deadlocked state,
  and [g] be a finite graph such that [g] is the finite WFG of [s].
  We can construct a totally deadlocked state [s'] such that the finite WFG
  of [s'] is a subgraph of [g].
  The proof unfolds the definition of deadlocked to obtain [s'].
  We obtain the finite WFG of [s'] from Lemma [wfg_of_total], which is nonempty,
  because totally deadlocked states are nonempty.
  Finally, we get that [g'] is a subgraph of [g] from Lemma [tedge_partition].
*)

Lemma deadlocked_inv:
  exists s' g',
  TotallyDeadlocked s' /\
  g' <> nil /\
  WFG_of s' g' /\ 
  Graph.subgraph (Edge g') (Edge g).
Proof.
  intros.
  unfold Deadlocked in *.
  destruct is_deadlocked as (tm, (tm', (Hp, Hd))).
  exists (get_phasers s, tm).
  assert (Hwfg: exists g', WFG_of (get_phasers s, tm) g'). {
    apply wfg_of_total.
  }
  destruct Hwfg as (g', Hwfg).
  exists g'.
  intuition.
  - apply totally_deadlocked_nonempty with (g:=g') in Hd; repeat auto.
  - unfold Edge in *.
    unfold Graph.subgraph.
    intros.
    unfold WFG_of in *.
    rewrite wfg_spec in *.
    apply totally_deadlocked_edge with (s:=(get_phasers s, tm)) in H;
    eauto using tedge_conv.
Qed.
(* begin hide *)
End Bootstrap.
(* end hide *)

(** By Lemmas [deadlocked_inv] and [totally_deadlock_has_cycle]
    we get that there is a totally deadlocked state [s'] that yields
    from Lemma [deadlocked_inv] and state [s'] has a cycle.
    But since, the finite WFG [g'] of state [s'] is a subgraph of
    graph [g], then the finite WFG [g] of state [s] also has a cycle.  *)
Corollary completeness:
  forall (s : state),
  Deadlocked s ->
  exists c, TCycle s c.
Proof.
  intros.
  destruct (wfg_of_total s) as (g, Hwfg).
  destruct (deadlocked_inv s g) as (s', (wfg', (Hdd, (Hnil, (Hwfg', Hsg))))); auto.
  assert (Hc :  exists c, Graph.Cycle (Edge wfg') c). {
    eauto using totally_deadlock_has_cycle.
  }
  destruct Hc as (c, Hc).
  exists c.
  assert (Graph.Cycle (Edge g) c). {
    eauto using Graph.subgraph_cycle.
  }
  apply Graph.cycle_impl with (E:=Edge g); auto.
  intros.
  apply Hwfg in H1.
  assumption.
Qed.
