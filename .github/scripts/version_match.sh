version='lajf0.0.3'
if [[  $version =~ ^([0-9]+\.){0,2}(\*|[0-9]+)$ ]]; then
 echo true
else
 echo "ERROR:<->invalidated version: '$version'"
 exit 1
fi