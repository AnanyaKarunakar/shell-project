#Data types
#!/bin/bash

NUMBER1=100
NUMBER2=200

TIMESTAMP=$(date)
echo "Script executed at: $TIMESTAMP"
#SUM=$NUMBER1+NUMBER2
SUM=$(($NUMBER1+$NUMBER2))

echo "SUM of $NUMBER1 and $NUMBER2 is: $SUM"

#variables

#!/bin/bash

PERSON1=$1
PERSON2=$2

echo "$PERSON1:: Hey $PERSON2, How are you?"   		# to differ normal text and variable that why we represent variable with $
echo "$PERSON2:: Hello $PERSON1, I am fine. How are you doing?"
echo "$PERSON1:: I am fine too. What's up?"
echo "$PERSON2:: Nothing, Just going to Mars now, will you come"
echo "$PERSON1:: Sorry, you carry on! I will come once yu come back"
echo "$PERSON2:: Ho thagt's great Idea"
echo "$PERSON1:: Sure!!"