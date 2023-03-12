### Powershell 4.0

########################################################################
## This script is designed to submit scheduled access RFCs for users and
## associated stack IDs defined in CSV file.  This example essentially
## schedules users access 24x7 for a week from the defined $startDteTme
########################################################################

########################################################################
## NOTE:  Ensure the following entries are correct for each run
########################################################################

# Add 30 seconds to start time to allow enough time to process 1 occurrence of
# all users i.e. if there are more the 25-30 users then increase the number of seconds!
##$startDteTme = Get-Date
##$startDteTme = $startDteTme.AddSeconds(30)
## Following is example to specify a future start date and time (UTC)
$startDteTme = Get-Date "2020-03-09 09:50:00Z"


# set basic parms about the environment this runs for
# The Profile/Region should be consistent with the submitting user's set-up in dxc-aws-fedsso.py script 
$Env:AWS_PROFILE = "PRDefault" 
$Env:AWS_DEFAULT_REGION = "us-east-1"
$Env:AWS_DEFAULT_OUTPUT = "text"

# This VPC ID will vary based on targeted AWS environment for RFC submissions
$awsVpcId = "vpc-09cce781c34b16ad9"  

# Location will depend on where the CLI scripts are installed and input CSV file to be processed
$processingDirectory = "C:\Users\srajendran84\Desktop\Misc\AWS Migration\RFC\create-scheduled-rfc\create-scheduled-rfc"
$userStackCsvFile = "$processingDirectory\inputfile-users.csv"


########################################################################
# The following two entries drives the number of sequental requests for each user 
########################################################################
$requestedNumberOfHours = 8 
$refreshNumberOfHours = 7.75
$numberOfIterations = 21 

#$numberOfIterations = 3 


## we refresh the RFCs every 7.75 hours to ensure that they are updated 
## prior to expiration.  So if you want to generate 5 days worth of RFCs
## then you would use formula (# days * 24 hours/day) / (refresh interval)
##  (5*24)/7.75 = 16 iterations (22 iterations for 7 days)

########################################################################
## Defaults and per users customizations that may need updated
########################################################################

########################################################################
# Process Requests
########################################################################
## File path for the Grant Access Params
$grantAccessParams = "$processingDirectory\GrantAccessParams.json"
## File path for the Grant Access RFC
$grantAccessRfc = "$processingDirectory\GrantAccessRfc.json"

$hashtable = import-csv "$userStackCsvFile"

For ($i=0; $i -lt $numberOfIterations; $i++) {
        
    foreach ($line in $hashtable) {

        (Get-Content $grantAccessParams) | Foreach-Object {
            $_ -replace "userdomain", "$($line.userdomain)" `
            -replace "acctname", "$($line.acctname)" `
            -replace "awsVpcId", "$awsVpcId" `
            -replace "requestedNumberOfHours", "$requestedNumberOfHours" `
            -replace "stackvalue", "$($line.stackid)" 
        } | Set-Content ./GrantAccessParamsSubmit.json
        
        # For each user/record being processed, bump up the number of seconds on the start time by 30 so we don't submit too many requests for the same time (2/minute)
		# Note:  Currently defined for 2/minute.  In the past, AWS has recommended throttling down to 6/min (every 10 seconds) but at times that has been an issue for Oklahoma.
        $startDteTme = $startDteTme.AddSeconds(30)
    
        $incrementedHours = $refreshNumberOfHours * $i
        ## start 30 minutes prior to the expiration time
        $calculatedStartTime = $startDteTme.AddHours($incrementedHours)
        $calculatedStartTimeIso8601 = $calculatedStartTime.ToUniversalTime().ToString("yyyyMMddTHHmmssZ")

        $json2 = Get-Content $grantAccessRfc
        $json2 = $json2 -replace "titleSubject", "$($line.titleSubject)" `
                        -replace "changeTypeRfc", "$($line.changetyperfc)" `
                        -replace "accessStartTime", "$calculatedStartTimeIso8601" | Set-Content .\GrantAccessRfcSubmit.json

        Write-Output "$($line.acctname.PadRight(11)) - $calculatedStartTimeIso8601"

        $rfcId = aws amscm create-rfc --cli-input-json file://GrantAccessRfcSubmit.json --execution-parameters file://GrantAccessParamsSubmit.json
        aws amscm submit-rfc --rfc-id $rfcId
    }

    Write-Output " "
}
