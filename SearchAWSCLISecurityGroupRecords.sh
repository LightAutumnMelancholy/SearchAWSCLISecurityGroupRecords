#!/bin/bash

while getopts "p:r:h" arg; do
    case $arg in
        p)
          profileName=${OPTARG}
          ;;
        r)
          regionForQuery=${OPTARG}
          ;;
        h)
          cat <<- EOF
          [HELP]: ### SearchAWSCLISecurityGroups. Go find AWS Security Groups in all VPCs. ###

          [EXAMPLE]: scriptname -r us-west-1 -p my_aws_profile

          [REQUIREMENTS]: This script requires only two arguments -r and -p, and requires the user to have setup aws profiles setup in
		  order to use this tool.

         [REQUIRED ARGUMENTS]:
            -r) [region to query] [STRING] This option refers to the region the security group belongs in.
            -p) [profile] [STRING] This option refers to the profile to be used for AWS. This should exist in $HOME/.aws/credentials.

         [OPTIONAL ARGUMENTS]:
            -h) [HELP] [takes no arguements] Print this dialog to the screen.
EOF
         exit 0
         ;;
      *)
         printf %"%s\n" "Incorrect syntax, try -h for help"
         exit 0
         ;;
    esac
done

trap ctrl_c INT

if [[ -z $profileName ]] || [[ -z $regionForQuery ]]; then
        printf "%s\n" "Missing required arguements, please see -h for help"
        exit 1
fi

function ctrl_c() {
        echo "** Caught SIGINT: CTRL-C **"
        exit 1
}
function getRecords() {
        securityGroups=$(aws ec2 describe-security-groups --profile $profileName --region $regionForQuery --output json | grep -i GroupId | sed -e s'/\"//g;s/GroupId\://g;s/\,//g;s/ //g' | sort | uniq -u)
        for secGroup in $securityGroups
            do 
                    printf "%s\n" "[INFO]: Checking $secGroup in $profileName :"
                    aws ec2 describe-security-groups --group-id $secGroup --profile $profileName --region $regionForQuery >> /tmp/$secGroup.result
                    if [[ -s /tmp/$secGroup.result ]]; then
                        vpcId=$(grep VpcId /tmp/$secGroup.result)
                        commonName=$(grep GroupName /tmp/$secGroup.result)
                        echo -e "\033[33;5;7m[INFO]: Success, found group:\033[0m"
                        printf "%s\n" "[INFO][Security Group]:] Group Name: $commonName" "[INFO][Security Group] VPC: $vpcId"
                        grep 'IpPermissions\|FromPort\|CidrIp\|ToPort\|IpPermissionsEgress' /tmp/$secGroup.result | sed s'/\"//g;s/\,//g;s/\[//g;s/\]//g'
                        obviouslyDangerous=$(sed -n '/IpPermissionsEgress/q;p' /tmp/$secGroup.result | grep '0.0.0.0/0')
                        if [[ $? -eq 0 ]] && [[ -n $obviouslyDangerous ]]; then
                            	echo -e "[WARN]: \e[31mThis looks dangerious, world readable Cidr Block on INGRESS in this security group:"
                                printf "%s\n" "$obviouslyDangerous"
                        fi
                        rm -f /tmp/$secGroup.result
                    else
                        printf "%s\n" "[WARN]: Nothing to report."
                        rm -f /tmp/$secGroup.result
                     fi
        done
}
getRecords
