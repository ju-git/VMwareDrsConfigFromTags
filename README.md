VMware DRS config from Tags.
----

### Synopsys 
  Script to create VMWware DRS Groups and rules based on VMware Tags and a rules file. 

### How it works ? 
  This scripts reads a Rules file (default : .\drs_rules\drs.csv), and the Tags placed on VMs and Hosts.
  
  Based on this, it creates all needed DRS Groups and Rules.
  
  The script is idempotent, when it's re-run, it will update what needed,
  or do nothing if nothing changed in the inputs.

### Quick start
  1/ Assign Tags on VM and host to define your groups.

  2/ Write the .\drs_rules\drs.csv file : describe the DRS rules you want to create. (Look at the sample file).

  3/ Run the script.  
  
### FAQ : 

Q: What is this script ?

A: It creates DRS Rules based on a rules file and tags placed on VMs and hosts.


Q: in 3 lines, how to use it ?

A: Assign Tags on VM and host to define your groups.
     
     Then, write the .\drs_rules\drs.csv file : describe the DRS rules you want to create. (Look at the sample file).
     
     Then, run the script..



Q: Why did you create it ?

A: If you have lots of VMs/Clusters/hosts, maintaining the DRS settings is boring, and everything is manual.



Q: Why not a Tags-Only solution ?

A: It was my original idea/goal, but was found to be either too limited (only one rule
   for each VM group) or too complicated (need to create per-rule specific tags and assignlots of tags).



Q: When should I run this script ?

A: Just after you assigned/removed tags used for your rules, or changed/added rules in the rules file.
    If you want you can run it periodicaly, no issue.
     You can also start it from the VCBA when a tag is added.
  
### Notes 
  Script created because vSphere only allows to create groups and rules based on static VM lists, 
  hard to maintain when you have lots of VMs.

### Examples 

  Simple syntax :

  .\createDrsTagRules.ps1 
  
  The name of the vCenter to connect to and the needed credentials will be prompted on first
  start, and will be saved in the .\script_config\ folder.

  BEFORE FIRST LAUNCH, you have to create the .\drs_rules\drs.csv file. The folder contain sample files.



  Working on only one of the clusters listed in the Rules File : 

  .\createDrsTagRules.ps1 -Cluster ClusterName




  Working with an alternative Rules file :

  .\createDrsTagRules.ps1 -DrsRulesFile .\Path\To\CustomFile.csv 
  



  Working with an alternative Credentials file :

  .\createDrsTagRules.ps1 -CredentialsFile .\Path\To\myCreds.file 



  Exit after the Rules Files was tested (No modification is performed on the vCenter) : 

  .\createDrsTagRules.ps1 -DrsRulesFileValidationOnly 



  Delete DRS Groups and Rules created by the sctipt.
  
  .\createDrsTagRules.ps1 -DeleteEveryRuleAndGroup
  
  The elements to delete are identified based on their name, which is prefixed by the string "TAG", hardcoded in the script.
  
  A list is displayed, and the user has to confirm before anything is deleted.

### Author

Original script : Julien AILHAUD -  Mail :    julien 
                                              at ailhaud dot com
                                    
                                    LinkedIn  : Julien AILHAUD
                                    https://www.linkedin.com/in/julien-ailhaud-ba6bb6/
                                    
                                    Facebook  : Julien AILHAUD
                                    https://www.facebook.com/julien.ailhaud/
                                    
                                    Twitter   : @curbans
                                    https://twitter.com/curbans
                                    (Don't use Twitter)

Software hosted at : https://github.com/ju-git/VMwareDrsConfigFromTags

### Changelog

Version : 2022.06.07.0001
    - Skip Rules file check when the Delete option is used.

Version : 2022.06.03.0001
    - Initial release.
    - Change Rules and VM to host rules only when enable status or related objects were changed.
    - Avoid redundant updates when a VM or Host Group is used in more than one rule.
    - Display a warning when the DrsRulesFile AND DeleteEveryRuleAndGroup params are given, 
      to point that the delete code don't read things from the Rules file.

### License

BSD 3-Clause License

Copyright (c) 2022, Julien AILHAUD
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this
   list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice,
   this list of conditions and the following disclaimer in the documentation
   and/or other materials provided with the distribution.

3. Neither the name of the copyright holder nor the names of its
   contributors may be used to endorse or promote products derived from
   this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


### Todo list

Known issues : 
    - Not tested on complex VMware setup (Linked Mode, ...)


Core code
    - Replace -match by -eq when it's appropriate

    - Use Functions ? :)

    - Use local credential store of Windows ?

    - Create Automated tests for CI/CD

    - Gain skills about PS exceptions management and use them

    - Create GUI to create the DRS rules file.

    - Enforce max length of the rule names (Max rulename size is 80 char.
      You can Limit your tags to 29 chars to avoid any issue)

    - Tool to create the configuration from existing, manually made DRS settings ?
    
English text
    - Fix english text

    - Put all messages in vars
    
    - Make messages more uniform

