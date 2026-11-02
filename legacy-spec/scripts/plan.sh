#!/usr/bin/env bash
# plan.sh --inventory spec/_state/inventory.tsv --max-lines 4000 [--out spec/_state/units.tsv]
# Groups text files into units that fit a context window. Starts at the first path component and
# descends into any directory whose total exceeds --max-lines. A single file over the limit is its
# own unit, flagged "oversize" (the skill reads it in sections).
# Output: unit_id<TAB>unit_path<TAB>files<TAB>lines<TAB>flag
set -uo pipefail
INV=""; MAX=4000; OUT=""
while [ $# -gt 0 ]; do case "$1" in
  --inventory) INV="$2"; shift 2;; --max-lines) MAX="$2"; shift 2;; --out) OUT="$2"; shift 2;; *) echo "unknown $1" >&2; exit 2;; esac; done
[ -f "$INV" ] || { echo "no inventory: $INV" >&2; exit 2; }
[ -n "$OUT" ] && exec >"$OUT"
awk -F'\t' -v MAX="$MAX" '
function ncomp(p,  n){ n=split(p,A,"/"); return n }
function unit(p,d,  n,i,s){ n=split(p,A,"/"); if(d>=n) d=n-1; if(d<=0) return "."; s=A[1]; for(i=2;i<=d;i++) s=s"/"A[i]; return s }
$6=="text" { N++; path[N]=$1; ln[N]=$3; dep[N]=1 }
END {
  changed=1
  while(changed){ changed=0; delete tot
    for(i=1;i<=N;i++){ u=unit(path[i],dep[i]); tot[u]+=ln[i] }
    for(i=1;i<=N;i++){ u=unit(path[i],dep[i]); if(tot[u]>MAX && dep[i] < ncomp(path[i])-1){ dep[i]++; changed=1 } }
  }
  delete tot; delete cnt
  for(i=1;i<=N;i++){ u=unit(path[i],dep[i]); tot[u]+=ln[i]; cnt[u]++ ; if(ln[i]>MAX) big[u]=1 }
  n=0; for(u in tot) order[++n]=u
  # simple sort
  for(i=1;i<=n;i++) for(j=i+1;j<=n;j++) if(order[j]<order[i]){ t=order[i]; order[i]=order[j]; order[j]=t }
  for(i=1;i<=n;i++){ u=order[i]; id=u; gsub(/[^A-Za-z0-9]+/,"-",id); gsub(/^-|-$/,"",id); if(id=="") id="root"
    flag=(tot[u]>MAX)?"oversize":"ok"; if(big[u]) flag="oversize"
    printf "%s\t%s\t%d\t%d\t%s\n", tolower(id), u, cnt[u], tot[u], flag }
}' "$INV"
