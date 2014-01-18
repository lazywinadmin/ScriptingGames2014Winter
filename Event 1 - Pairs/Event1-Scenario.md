Event 1 - Pairs
========================

Author: Ed Wilson
-------

Your company has decided to have secret pals to improve morale. The idea is that each person in the department will be assigned the name of a team mate, and once a quarter you have to hide a low cost gift on his / her desk. Your manager has appointed you to write the script that will create the random name assignments. Here are the names of the people in the department for which you need to create the pairs:
 
Syed, Kim, Sam, Hazem, Pilar, Terry, Amy, Greg, Pamela, Julie, David, Robert, Shai, Ann, Mason, Sharon
 
An appropriate output is simple two names: such as
 
Sam, Hazem
Ann, Sharon
Syed, Terry
<etc>
 
Optionally the pairs should be saved to a file. The files should be named such that it is easy to see when they were created.

 
There are 16 names in the list, so that would be 8 pairs BUT your solution must work with more pairs than that. In addition, it should issue a warning if there is an odd number of names. At that point, you should be given the option to select a person to have TWO secret pals.

One of the project managers in your company heard about this from your manager and decided a similar approach could solve one of his problems. He is running a development project and depending on the phase of the project could have anywhere from 8 to 50 people working on the project. The software being developed is very important to the company’s future plans so he has the developers working in pairs so that knowledge is shared.
The project manager needs you to modify your code so that:

* It can handle varying numbers of people
* The results of each run need to be saved
* The pairings will be run every 1 to 2 weeks
* The PM wants to be able to specify up to 5 people (0-5) who will be the primary of any pair. They should never pair with another primary
* The primaries can change at each stage of the project
* No two people should work with each other until they have been paired with at least 4 other people 
* The code should have the option to email the people to inform them who their next partner will be. The project manager should be included in any communications.

Your code will be used by other project managers with similar needs so should be production ready with:
* Ability to optionally report on progress
* Full error checking, reporting and handling
* Ability to accept pipeline input where appropriate
* Help is available
* Input is validated


You are expected to have two solutions – the one for your manager and the one for the project manager. You are encouraged to share code between the two solutions.
In your entry submission, include a transcript that shows you running the command as described in this scenario.
