Require Import ResourceDependency.
Require Import Semantics.
Require Graphs.FGraphs.
Module F := Graphs.FGraphs.
Require Import Graphs.Core.
Require Import Vars.
Require Import Syntax.
Require Import PairUtil.
Import Map_TID_Extra.

Section Basic.
  Variable s:state.

Lemma tedge_inv:
  forall w t t',
  TWalk s w ->
  F.Edge w (t, t') ->
  exists e,
  WaitsFor s t e /\ Impedes s e t'.
Proof.
  intros.
  apply in_edge with (Edge:=G.Edge (WFG s)) in H0.
  inversion H0.
  simpl in *.
  subst.
  exists b.
  intuition.
  assumption.
Qed.

Lemma vertex_in_tasks:
  forall t w,
  TWalk s w ->
  F.In t w ->
  Map_TID.In t (get_tasks s).
Proof.
  intros.
  simpl in *.
  inversion H0 as ((t1, t2), (Hin, Hpin)).
  destruct Hpin as [H2|H2].
  - subst; simpl in *.
    apply tedge_inv in Hin.
    + destruct Hin as (r, (Hwf, _)).
      apply waits_for_in_tasks in Hwf.
      assumption.
    + auto.
  - subst. simpl in *.
    apply tedge_inv in Hin.
    + destruct Hin as (r, (_, Himp)).
      apply impedes_in_tasks in Himp.
      assumption.
    + auto.
Qed.

Section TotallyDeadlocked.
Variable w:t_walk.
Variable is_cycle: TCycle s w.
Variable vertex_in_tasks:
  forall t, F.In t w <-> Map_TID.In t (get_tasks s).

Let Hwalk: TWalk s w.
Proof.
  intros.
  inversion is_cycle.
  assumption.
Qed.

Lemma blocked_in_walk:
  forall t e,
  WaitsFor s t e ->
  exists t', F.Edge w (t', t).
Proof.
  intros.
  unfold WaitsFor in *.
  destruct H as (p, (Hin, _)).
  apply mapsto_to_in in Hin.
  rewrite <- vertex_in_tasks in Hin.
  assert (H := Hin).
  apply F.pred_in_cycle with (v:=t) in is_cycle.
  destruct is_cycle as (t', (He, He')).
  exists t'.
  auto.
  auto.
Qed.

Lemma in_inv_left:
  forall t t',
  List.In (t, t') w ->
  Map_TID.In t (get_tasks s).
Proof.
  intros.
  simpl in *.
  apply vertex_in_tasks.
  unfold F.In.
  unfold In.
  exists (t, t').
  unfold F.Edge.
  intuition.
  apply pair_in_left.
Qed.

Lemma vertex_to_blocked:
  forall t,
  F.In t w ->
  exists e, WaitsFor s t e.
Proof.
  intros.
  apply F.succ_in_cycle with (E:=TEdge s) in H; repeat auto.
  destruct H as (t', (He, Hi)).
  apply tedge_inv in Hi.
  destruct Hi as (r, (Hw, _)).
  exists r.
  assumption.
  assumption.
Qed.

Lemma blocked_to_impedes:
  forall t e,
  WaitsFor s t e ->
  exists t', Impedes s e t' /\ exists e', WaitsFor s t' e'.
Proof.
  intros.
  assert (Hblocked := H).
  apply waits_for_in_tasks in H.
  apply vertex_in_tasks in H.
  apply F.succ_in_cycle with (E:=TEdge s) in H; repeat auto.
  destruct H as (t', (He, Hin)).
  assert (Hx := Hin).
  apply tedge_inv in Hin.
  destruct Hin as (e', (Hw, Hi)).
  exists t'.
  assert (e' = e).
  apply waits_for_fun with (e:=e) in Hw; r_auto.
  subst.
  intuition.
  assert (F.In t' w).
  apply in_def with (e:=(t, t')).
  apply pair_in_right.
  assumption.
  apply vertex_to_blocked.
  assumption.
  assumption.
Qed.

Lemma soundness_totally:
  TotallyDeadlocked s.
Proof.
  intros.
  unfold TotallyDeadlocked.
  intros.
  intuition.
  - unfold AllTasksWaitFor; intros.
    assert (F.In t w).
    apply vertex_in_tasks; assumption.
    assert (exists t2, TEdge s (t, t2)).
    apply F.succ_in_cycle with (E:=TEdge s) in H0; repeat auto.
    destruct H0 as (t2, (Hc, _)); exists t2; auto.
    destruct H1 as (t2, H1).
    apply tedge_spec in H1.
    destruct H1 as (r', (Hwf1, Himp1)).
    exists r'; assumption.
  - unfold AllImpedes; intros.
    assert (Hblocked := H).
    apply blocked_to_impedes in H.
    destruct H as (t', (Him, (r', Hv))).
    exists t'.
    assumption.
  - inversion is_cycle.
    exists v1.
    apply in_inv_left with (t':=v2).
    subst.
    apply List.in_eq.
Qed.
End TotallyDeadlocked.
End Basic.

Section Soundness.
Variable w:t_walk.
Variable s : state.
Variable is_cycle: TCycle s w.
Let split : tid -> prog -> bool := (fun t (p:prog) => F.mem TID.eq_dec t w).

Let part := Map_TID_Props.partition split (get_tasks s).

Let Hpart: Map_TID_Props.Partition (get_tasks s) (fst part) (snd part).
Proof.
  apply Map_TID_Props.partition_Partition with (f:=split).
  auto with *.
  unfold part.
  auto.
Qed.

Let split_to_vertex:
  forall t e,
  split t e = true ->
  In (F.Edge w) t.
Proof.
  intros.
  unfold split in *.
  apply F.mem_prop in H.
  assumption.
Qed.


Let vertex_to_split:
  forall t p,
  In (F.Edge w) t ->
  split t p = true.
Proof.
  intros.
  apply F.mem_from_prop with (eq_dec:=TID.eq_dec) in H.
  unfold split in *.
  assumption.
Qed.

Let deadlocked_in_right:
  forall t,
  Map_TID.In t (fst part) -> In (F.Edge w) t.
Proof.
  intros.
  apply in_to_mapsto in H.
  destruct H as (e, H).
  rewrite Map_TID_Props.partition_iff_1 with
     (f:=split) (m:=(get_tasks s)) in H.
  destruct H as (H1, H2).
  apply split_to_vertex with (e:=e).
  assumption.
  auto with *.
  auto.
Qed.

Let ds := ((get_phasers s), (fst part)).

Let deadlocked_in_left:
  forall t,
  In (F.Edge w) t -> Map_TID.In t (fst part).
Proof.
  intros.
  assert (Hin := H).
  apply vertex_in_tasks with (*d:=d*) (s:=s) (t:=t) (w:=w) in H.
  apply in_to_mapsto in H.
  destruct H as (p, Hmt).
  apply vertex_to_split with (p:=p) in Hin.
  assert (Hg: Map_TID.MapsTo t p (get_tasks s) /\ split t p = true).
  intuition.
  rewrite <- Map_TID_Props.partition_iff_1
    with (m1:=(fst part)) in Hg.
  apply mapsto_to_in in Hg.
  assumption.
  auto with *.
  auto.
  inversion is_cycle.
  auto.
Qed.

Let deadlocked_in:
  forall t,
  (In (F.Edge w) t <-> Map_TID.In t (fst part)).
Proof.
  intros.
  split.
  apply deadlocked_in_left; r_auto.
  apply deadlocked_in_right.
Qed.

Let deadlocked_tasks := fst part.

Let tid_in_walk:
  forall t,
  F.In t w ->
  exists p,
  Map_TID.MapsTo t p (get_tasks s) /\
  Map_TID.MapsTo t p deadlocked_tasks.
Proof.
  intros.
  apply deadlocked_in in H.
  apply in_to_mapsto in H.
  destruct H as (p, H).
  exists p.
  intuition.
  - unfold Map_TID_Props.Partition in Hpart.
    destruct Hpart as (Hdj, Hrw).
    rewrite Hrw.
    auto.
Qed.

Let blocked_conv:
  forall t r,
  F.In t w ->
  WaitsFor s t r ->
  WaitsFor ds t r.
Proof.
  intros.
  unfold WaitsFor in *.
  destruct H0 as (p, (H1, H2)).
  exists p.
  simpl.
  intuition.
  apply tid_in_walk in H.
  destruct H as (p', (H4, H5)).
  apply Map_TID_Facts.MapsTo_fun with (e:=p') in H1; r_auto.
  subst.
  assumption.
Qed.

Let registered_conv:
  forall t r,
  In (F.Edge w) t ->
  Registered s t r ->
  Registered ds t r.
Proof.
  intros.
  unfold Registered in *.
  destruct H0 as (ph, H1); exists ph.
  intuition.
  destruct H3 as (r', H4).
  apply blocked_conv in H4.
  exists r'.
  assumption.
  assumption.
Qed.

Let t_edge_conv:
  forall e,
  List.In e w ->
  TEdge s e ->
  TEdge ds e.
Proof.
  intros.
  simpl in *.
  inversion H0; clear H0; subst.
  assert (Hw : WaitsFor ds a1 b).
    apply blocked_conv in H1; r_auto.
    apply in_def with (e:=(a1, a2)).
    apply pair_in_left.
    unfold F.Edge.
    assumption.
  (* eoa *)
  apply Core.aa with (b:=b).
  - assumption.
  - destruct H2 as (_, (ev, (H2, H3))).
    apply registered_conv in H2.
    + apply impedes_def with (t':=a1) (e':=ev); repeat auto.
    + apply in_def with (e:=(a1, a2)).
      apply pair_in_right.
      unfold F.Edge.
      assumption.
Qed.

Let t_edge_dd :
  List.Forall (TEdge ds) w.
Proof.
  rewrite List.Forall_forall.
  intros e Hin.
  apply_auto t_edge_conv.
  apply in_edge with (w:=w); r_auto.
  inversion is_cycle.
  assumption.
Qed.

Let t_walk_conv:
  TWalk ds w.
Proof.
  inversion is_cycle.
  rewrite H1 in *.
  apply walk_to_connected in H0.
  apply_auto walk_def.
Qed.

Let cycle_conv:
  TCycle ds w.
Proof.
  inversion is_cycle.
  apply cycle_def with (vn:=vn).
  - assumption.
  - rewrite H1 in *.
    apply t_walk_conv.
Qed.

Let vertex_in_tasks:
  forall t, F.In t w <-> Map_TID.In t (get_tasks ds).
Proof.
  intros.
  split.
  - apply deadlocked_in_left.
  - apply deadlocked_in_right.
Qed.

Let ds_totally_deadlocked :=
  soundness_totally ds w cycle_conv vertex_in_tasks.

Theorem soundness:
  Deadlocked s.
Proof.
  unfold Deadlocked.
  exists (fst part).
  exists (snd part).
  auto.
Qed.
End Soundness.
