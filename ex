OUTPUT_STATS = ("PCT_RANK_PREAGG", "PCT_RANK", "STD_DEV", "P75", "P95", "STATUS")
 
 
def build_output(
    df: pd.DataFrame,
    id_col: str = ID_COL,
    group_cols: tuple[str, ...] = GROUP_COLS,
    stats: tuple[str, ...] = OUTPUT_STATS,
    metrics: list[Metric] = METRICS,
    min_group_n: int = 1,
) -> pd.DataFrame:
    """One row per return: id, group columns, every input column, then metric columns.
 
    Metric columns are named <metric>__<stat>, e.g. cogs__per_receipts__PCT_RANK.
    PCT_RANK_PREAGG is the ratio (RATIO in the long output). Any column from
    compute_metrics can be requested in stats, e.g. PCT_REPORTING, N_RANKED, RAW_RATIO.
    Base columns are returned as filed; blanks are only treated as 0 inside the metrics.
    """
    if df[id_col].duplicated().any():
        dups = df.loc[df[id_col].duplicated(keep=False), id_col].unique()[:10]
        raise ValueError(f"{id_col} must be unique; duplicates include {list(dups)}")
 
    long = compute_metrics(df, id_col=id_col, group_cols=group_cols,
                           metrics=metrics, min_group_n=min_group_n)
    long = long.rename(columns={"RATIO": "PCT_RANK_PREAGG"})
 
    # Pivot each stat on its own so numeric columns stay float (a combined
    # pivot with STATUS would make every column object dtype).
    pieces = {stat: long.pivot(index=id_col, columns="METRIC", values=stat) for stat in stats}
    wide = pd.DataFrame(
        {f"{m.name}__{stat}": pieces[stat][m.name] for m in metrics for stat in stats}
    )
 
    lead = [id_col, *group_cols]
    base = df[lead + [c for c in df.columns if c not in lead]]
    return base.merge(wide, left_on=id_col, right_index=True, how="left", validate="on
