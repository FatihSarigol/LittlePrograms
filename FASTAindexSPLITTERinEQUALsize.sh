###FASTA INDEX SPLITTER-NEARLY EQUALLY BASED ON LENGTHS####
#########written with love by fatih sarigol################

#####EXPLANATION#######
##Imagine you have 30000 scaffolds(or contigs or chromosomes etc) in your reference genome and you want to run some analyses on it that take so much time
##You can manually subset it to smaller pieces, for example by splitting its index into 100 pieces with 300 scaffolds in each
##But distribution of lengths of the scaffolds always changes, and doing so may lead to some subsets taking much longer time than some others
##This code calculates the total length of the fasta file, and splits its index into subsets with almost equal total genome lengths
##You can choose how many subsets you want, which you can use in a job array easily. The names of the subsets will be INDEX1 INDEX2 etc.
##A scaffold will always stay in a single subset and will never be split into 2 different subsets.

###INSTRUCTION OF USAGE###
##AFTER MAKING IT EXECUTABLE (such as by "chmod +x FASTAindexSPLITTERinEQUALsize.sh"), RUN THIS LITTLE PROGRAM AS:
#./FASTAindexSPLITTERinEQUALsize.sh samtoolsExecutable fastaFile numberOfDivisions
##example usage; if we want to split the fasta index into 15 nearly equal subsets:
#./FASTAindexSPLITTERinEQUALsize.sh /MyPrograms/samtools1.9/samtools MyGenome.fa 15

###THE CODE###
#!/bin/bash

#Following 3 definitions are variables you define on the command line after the program executable:

#Define the location of samtools program executable (if it is in your environment -such as via conda- simply type samtools on the command line)

samtools=$1

#Choose your fasta file for indexing (and splitting its index)

MYFASTA=$2

#Choose the number you want to divide your fasta index to, you will have 15 files with nearly equal total lengths for example

DIVIDE=$3


#Get fasta index using samtools

$samtools faidx $MYFASTA

#Get first 2 columns with Scaffold names and lengths

cut -f1,2 $MYFASTA.fai > indexCOL12

#Calculate total length of the fasta file

awk '{total += $2} END {print total}' indexCOL12 > totalSIZE

#Define a bash variable using totalSIZE result

TOTALsize=$(cat totalSIZE)

#Define TOTALsize and DIVIDE variables inside the awk program, add the lengths of Scaffolds, when the total reaches the division of TOTALsize/DIVIDE print SPLIThere
#If the total didn't reach that value yet, simply print the line as it is. Once the total reaches that value, restart the total to zero and start counting again

awk -v TOTSIZE="$TOTALsize" -v DIV="$DIVIDE" 'BEGIN {s = 0}{s += $2; if (s >= TOTSIZE/DIV ) {print $0 "\t" "SPLIThere"; s = 0} else print $0}' indexCOL12 > FastaIndexToSplit

#Add SPLIThere as 3rd column to first line (We need the 2 following steps for csplit to make it start our indexes from 1 instead of 0)

sed -i '1s/$/\tSPLIThere/' FastaIndexToSplit

#Add a first line with zero (anything else would also work)

sed -i '1 i\0' FastaIndexToSplit

#Split from lines with the word "SPLIThere" in it, name the new split files starting with "INDEX"

csplit -s -f INDEX -z FastaIndexToSplit /SPLIThere/ {*}

#Clear the third column which has SPLIThere in some files

sed -i -r 's/(\s+)?\S+//3' INDEX*

#Rename the INDEX files to be accepted by SGE array jobs

for f in *X0*; do mv -- "$f" "${f:0:6-1}${f:6}"; done

#Add a second column with zero to convert the index lines into bed file

for i in *INDEX*; do awk '{print $1 "\t" "0" "\t" $2}' ${i} > TEMP ; mv TEMP ${i}; done

#Your new index bed files are ready to go!

#Remove intermediate files

rm indexCOL12 totalSIZE FastaIndexToSplit INDEX0 $MYFASTA.fai

echo "Your fasta index file has been split to nearly equal total lengths of $3 subsets in bed format! :)"
