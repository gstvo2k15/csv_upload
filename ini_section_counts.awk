BEGIN {
  sec = ""
  ignore = 1
}

/^[[:space:]]*\[[^]]+\][[:space:]]*$/ {
  header = $0
  gsub(/^[[:space:]]*\[/, "", header)
  gsub(/\][[:space:]]*$/, "", header)

  sec = header


  ignore = (sec ~ /:(children|vars)$/) ? 1 : 0
  next
}

sec == "" { next }

ignore == 1 { next }

/^[[:space:]]*$/ { next }
/^[[:space:]]*[#;]/ { next }

{
  c[sec]++
}

END {
  for (s in c) {
    printf "%s\t%d\n", s, c[s]
  }
}
