function re_pair() {
  id=`blueutil --paired | grep "Magic Keyboard" | grep -Eo '[a-z0-9]{2}(-[a-z0-9]{2}){5}'`
  name=`blueutil --paired | grep "Magic Keyboard" | grep -Eo 'name: "\S+"'`
  echo "unpairing with BT device $id, $name"
  blueutil --unpair "$id"
  echo "unpaired, waiting a few seconds for Magic Keyboard to go to pairable state"
  sleep 3
  echo "pairing with BT device $id, $name"
  blueutil --pair "$id" "0000"
  echo "paired"
  blueutil --connect "$id"
  echo "connected"
}