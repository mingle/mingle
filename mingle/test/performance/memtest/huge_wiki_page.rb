#  Copyright 2020 ThoughtWorks, Inc.
#  
#  This program is free software: you can redistribute it and/or modify
#  it under the terms of the GNU Affero General Public License as
#  published by the Free Software Foundation, either version 3 of the
#  License, or (at your option) any later version.
#  
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU Affero General Public License for more details.
#  
#  You should have received a copy of the GNU Affero General Public License
#  along with this program.  If not, see <https://www.gnu.org/licenses/agpl-3.0.txt>.

load File.dirname(__FILE__) + '/../../config/environment.rb'

def run
  puts(Benchmark.measure do
    Project.new.with_active_project do
      page = Page.new(:content => WIKI_PAGE)
      page.formatted_content(FakeViewHelper.new)
    end
  end)
end

class FakeViewHelper
  def link_to(*args); '' end
  def auto_link(*args); '' end
end

WIKI_PAGE = <<-HERE
[[ < User testing overview|User testing]]
|
[[Summary of this output]]

h2. Projects list

* Good for the app to have a concept of my default project and for that to be at the top - anything to save me time [Josh P.]

bq. _Story added #698: Dan North gave similar feedback on the early storyboards_

* Not sure why we have 'New project' twice [Dennise O.]

bq. _In progress: This will go as we transition to placing actions consistently at the top of pages_

* Not really clear what the space in the sidebar is doing here... [Dennise O.]

bq. _In progress: We will review, on a page by page basis, which overall template is best_

h2. Project home page / overview

* Expect a level of rolled up info - e.g. status, number of issues, etc. [Shelley B.]

bq. _In progress #702: We are working on mock-ups of possible dashboard pages_

* Can't find any obvious place to import [Josh P.] (to the degree that couldn't proceed with task w/o direction) [Shelley B.]  [Mike Mc.]  [Ben H.]  [Dennise O.]

bq. _Story added #699: All users had trouble with this - agreed that this is to a certain extent an artifact of the tasks given them, however the early boards provided for a 'Getting started...' panel with links to key activities which I think we should consider revisiting_

* (Having explored a link from the overview page) Not sure how to get back to the starting page [Shelley B.]

bq. _Story added #701: I would like to discuss having some more help for users as the navigate the Wiki, e.g. 'recently visited pages' or a breadcrumb..._

* Expect some form of dashboard for the project - something visual, prefer this by far [Mike Mc.]

bq. _See #702 - we're working on mock-ups_

* (Tagging can be interpreted as a search) [Mike Mc.]

bq. _In progress: Believe this is covered off by the clean up to the sidebar and improved labeling of same_

* Expecting to see risks, issues, master story list, etc. [Dennise O.]

bq. _See #702 - we're working on mock-ups_

* Am most focused on bugs and stories [Dennise O.]

h2. Import

* Because of the word 'import' I was expecting to have a file dialog [Lindsay R.]  [Shelley B.]  [Ben H.]  [Dennise O.]

bq. _Story added #700: Sorry if this is a duplicate, but I couldn't find a story for file import and export_

* It would be nice if it would deal with duplicates on the upload [Josh P.]  [Dennise O.]

bq. _Relates to story #211 _

* Would like file import  - c.f. Google docs [Jason Y.]

bq. _See story #700 _

* I missed the part about the header in the instructions [Lindsay R.]

bq. _Story added #703: Believe we need to clean up the import screens - in terms of language of instructions and controls_

* Import is great to have [Shelley B.]

h2. Import - Preview

* I was expecting this type of preview with the columns broken out [Lindsay R.]  [Shelley B.]  [Josh P.]  [Mike Mc.]  [Ben H.]
* I've got this question (due to absent header row) but I can't act on it - i'd like a way to action it there - plus the wording is confusing, it doesn't match the instructions [Lindsay R.]

!Import_question.png!

bq. _See story #703 _

* Would have expected it to ask me what delimiters I wanted to use - like Excel [Dennise O.]

bq. _Nice to have - Suggest this is not a high priority for R1_

* I can see me getting comfortable with this after a couple of tries but it's hard first time around [Lindsay R.]
* I've no idea what the drop-downs do [Lindsay R.]  [Shelley B. - perhaps they're auto-filters like in Excel?] Not immediately clear what the drop-downs are doing - what's a "tag-group"? [Josh P.]  [Ben H.] If the basic import worked I'd be unlikely to use the more advanced options [Dennise O.]

bq. _See story #703 - Simplify / clarify the default import process_

* The horizontal zebra bars had me associating 'ignore' with the drop-downs - confusing - then I have ignore in the drop-down to - what happens if I ignore the ignore? [Lindsay R.]

bq. _See story #703 - Simplify / clarify the default import process_

* Labeling of the drop-downs is confusing - should be something like "Import as..." c.f. Excel / Access [Ben H.]

bq. _See story #703 - Simplify / clarify the default import process_

* Like the idea of preview [Mike Mc.] - implementation to complex [Shelley B.]

bq. _See story #703 - Simplify / clarify the default import process_

* With the added complexity of the drop-downs and 'ignore' no longer sure what 'Accept' will lead to [Shelley B.]

bq. _See story #703 - Simplify / clarify the default import process_

* Would prefer language of 'Next' rather than 'Accept', 'Accept' feels like I'm locked into something [Ben H.]

bq. _See story #703 - Simplify / clarify the default import process_

* There's a lot of explanatory text - too much - should be more apparent what to do [Josh P.]  [Jason Y.]  [Ben H.]

bq. _See story #703 - Simplify / clarify the default import process_

* Text is clear [Mike Mc.]

* Could the app be more intelligent and only flag problems if it has them - rather than warning me up front in lots of text about what could go wrong (e.g. detect if there's a header row, or have me flag whether there is one of not - c.f. Excel) [Josh P]

bq. _See story #703 - Simplify / clarify the default import process_

* I expect the app to add this new content to the existing in story list form [Shelley B.]

h2. All list

* Post import it would be nice to see in the list which are new and which have been updated [Jason Y.]  [Ben H.]

bq. _Story added #704 - Nice to have but a good idea_

* Post import it would be nice for the list to default to showing the columns that were in my imported data - if feel like I've lost them - did I get all of them - where's the description col? [Ben H.]
* I'd expect the columns I had in my import to be displayed - I'm looking for priority but I can't see it [Dennise O.]

bq. _Unsure about this one - we could get into confusion overriding the existing set-up that people have - I think the sense of losing content was heightened by the fact that our 'All' view currently has only two columns and doesn't persist columns that are added - this we should overcome (see story #721 - Ability for selected columns chosen by the user to persist for the 'All' view)_

* Export / Import pretty obvious once on a list page [Josh P.]  [Jason Y.]  [Mike Mc.]
* Would expect all the actions to be in a similar location [Dennise O.]

bq. _Story added #718 - We do need to revisit the top action bar in the table view, e.g. should import be here? how can we make bulk change of properties / tags more obvious_

* Not clear what 'All' as the tab title refers to [Lindsay R.]

bq. _Believe it becomes quickly apparent after brief use_

* Don't understand why I can't see the types of card on the 'All' list [Shelley B.]

bq. _This will be addressed by our default template / scaffold which is in progress referenced by multiple stories_

* It's confusing to have 3 different ways to edit all labeled the same (in-line, detail, bulk) [Lindsay R.]  [Josh P.]  [Ben H.]  [Dennise O.]
* Expected clicking on the line to invoke the inline editing [Ben H.]
* Checkboxes are small [Ben H.]
* Inline edit was what I was expecting [Lindsay R.]
* 'Edit' link for the inline edit wasn't obvious - no underline [Mike Mc.]
* 'Save' and 'Cancel' options (for the inline edit) feel far removed - but it stored the changes when I hit enter which is what I'd expect [Lindsay R.]

bq. _Story created #719 - Need to revisit the different ways of accessing 'edit' and clarify them_

* Not clear how I action my bulk edit (not a problem to select them) - can't find anything relating to status (looked under 'More actions', tried right-click, tried sidebar as could see 'priority' there) [Shelley B.]  [Josh P.]  [Jason Y.]  [Mike Mc.]  [Ben H.]  [Dennise O.]

bq. _See story #718 - Revise table header to make bulk actions on items more intuitive_

* In the stats it refers to number and then there's the card column called number - perhaps the column should be 'id' [Lindsay R.]

bq. _See bug #720 - This is a good point - we should consider_

* Very annoying that selected columns don't persist on the 'All' view [Mike Mc.]
* Expect columns and sorting applied to persist [Lindsay R.]
* Would expect the column selection to be global [Dennise O.]

bq. _Story created #721 - This frustrated Mike mightily and did so any user who saw it (tasks didn't drive it out so only one or two did - I think this is really important to fix_

* Could we get an aggregate number at the top of the columns, e.g. the total number of stories at the top of the number column? [Mike Mc.]

bq. _Possibly in the future_

* Filter should auto-apply - would save a click and it's what I expect from other apps (e.g. Excel) [Mike Mc.]

bq. _Filter now has auto-apply - hurrah!_

* Headings in sidebar aren't clear [Ben H.]
* Not clear what the 'Save view as...' is saving - what it's scope is - does it add the stats to the Wiki? [Dennise O.]
* How do I manage my views? [Ben H.]

bq. _Story created #722 - Sidebar needs to be cleaned up with clearer headings and more intuitive grouping / ordering of content_

* Expected clearer position and iconography for 'Add card' [Ben H.]

bq. _Icons are gradually being added across the piece_

* Expected a column for each tag - or at least a tags column - for the non tag-group tags [Ben H.]
* Smaller values (e.g. iteration) should be centered in their column [Ben H.]

bq. _Story created #723 - for a tags column_

* Was looking for stats - good to see we have some [Dennise O.]

h2. Bulk edit view (iteration planning view)

* Actions should be consistently placed and labeled - here 'Save' is called 'Done' and sometimes it's at the top and sometimes it's at the bottom [Shelley B.]

bq. _Story created #724 - Action buttons / links should be consistently labeled and positioned_

* This works - but it would be nice to have a bulk edit where I enter once and it's applied to all - vs. having a subset which I then move through one by one [Shelley B.]  [Jason Y.]  [Ben H.]
* Arrived here to bulk change status - but few hints as to how I can now do that [Josh P.]

bq. _Story created #725 - Ability to change the properties of multiple (bulk) stories / bugs via an iTunes like bulk edit screen_

* How do I get back - I was in bugs and now I'm under 'All' [Ben H.]

h2. Bulk tag

* Why do I have multiple tag boxes? [Ben H.]

bq. _Will be addressed by the 'Build a better tag editor story - see #173 _

* Can I do a bulk remove of a tag? [Ben H.]

bq. _Story created #726 - Ability to do a bulk remove of a tag_

* Tag just isn't a term I, or most PMs, would understand - I wouldn't have looked here to set priority [Dennise O.]

bq. _We need an overarching principle which is about using comprehensible language_

* You can use the tag button to tag one card - so it's not really bulk - it's applying a value to one or more [Dennise O.]

h2. Bugs list

* (Didn't find a way to change status at a bulk level, i.e. without driving down to card detail - bulk edit and the 'tag' button was no at all obvious) [Lindsay R.]
* Not clear on tags being used for status, etc. [Lindsay R.]
* Can I change status using these? (indicating pseudo drop downs under the filter title in the side bar) - it's the only place I see status mentioned [Lindsay R.]

bq. _Story #718 will help to address this, as will clearer layout of the sidebar, story #722 _

* Seems to have lost my changes :( [Lindsay R.]

h2. Stories list

* Expected 'Stories' tab to be like the 'Bugs' tab aside from the the type and it was [Lindsay R.]
* (Pseudo drop-downs worked without pause for thought) [Lindsay R.]  [Josh P.]  [ Shelley B. ]  [Jason Y.]  [Mike Mc.]  [Ben H.]
* Expect the add story button to be placed along with the "Edit" and "Tag" because it's a similar action [Shelley B.]

bq. _See bug #718 - Revise table header to make bulk actions on items more intuitive_

h2. Story / bug edit

* 'Save' wording and position should be consistent [Shelley B.]  [Josh P.]  [Jason Y.]

bq. _See #724 - Action buttons / links should be consistently labeled and positioned_

* The fact that the screen updated (adding a tag) gave me the impression it was saved - but I lost the change [Jason Y.]
* My location has moved - I was under the stories tab - now when I'm editing the tab selected is 'All' - that's confusing [Shelley B.]
* It should return me to an appropriate list - e.g. if type bug to the bug list, but then again I started from the stories tab so perhaps I should go back there... [Jason Y.]
* As I added the story from the story tab I expected it to be typed that way and to appear in the story list (which it didn't as type was left as '(none-set)' [Shelley B.]
* Add should automatically obvious properties / attributes - e.g. type should be set as appropriate, status should be set to new [Josh P.]  [Jason Y.]  [Ben H.]
* Setting the type is the most important thing - I'd expect it first [Dennise O.]

bq. _The revised approach to creating new stories / bugs with the attributes of the current saved view should go some way to addressing these concerns - it means that newly created stories / bugs will have values for many of their properties and that the edit page will be under the expected tab_

* Having the drop-down hints is vital - they should be there from the start not just after you've built them up... [Josh P.]
* Like the drop-down suggestions [Mike Mc.]
* Adding comment language is different again - language for adding / saving / etc. should be consistent [Josh P.]

bq. _Story created #727 - The layout / presentation of the 'edit' and 'view' pages for stories / bugs / etc. should be consistent_

* Pseudo drop-downs are in alphabetical order - they should be in 'common-sense' order - e.g. by frequency or life-cycle [Josh P.]

bq. _Story created #728 - Ensure the default template (scaffold) orders tag-groups in a common sense manner_

* Clean-up inconsistent cases on tags / attributes - I should be able to enter them as I like - but the app should clean them up [Josh P.]

bq. _Feels like a nice-to-have as users can edit tags to clean this up themselves..._

* Be great to have a 'Save and add another' button to speed the process [Josh P.]

bq. _Story created #729 - Ability to 'Save and add another' when editing stories / bugs / etc._

* Good to have template for story entry, e.g "Ability to..." or "As a... I want... So that..." [Josh P.]

bq. _Feels like a nice-to-have as users / teams can implement this for themselves_

* Should be able to tab my way through the page - it's annoying I can't tab to, for example, set priority [Jason Y.]

bq. _Story created #730 - Ability to tab through pages - story / bug creation in particular - including the pseudo drop-down_

* Don't know how I could add another size if the one I wanted wasn't in the (pseudo) drop-down [Jason Y.]

bq. _There are at least two ways this is possible - need to pick up on the issue of help more generally - there's a comment to this effect under 'General' below_

* Would like to clone an existing story [Jason Y.]

bq. _Story created #731 - Abilty to clone or duplicate a story / bug / etc._

* Shortcut keys - would like to Ctrl + S to save [Jason Y.]

bq. _In play already as story #289 - Keyboard shortcut for card save_

* Having a list of stakeholders that a story relates to (that you can select from, e.g. 'requested by') would be useful [Mike Mc.]

bq. _This is already possible given the flexibility of the tag-groups_

* Initially missed the 'Update card' button - was looking on the right-hand side [Ben H.]
* Having the 'Update card' button below the fold is a bad idea [Dennise O.]

bq. _See story #724 - Action buttons / links should be consistently labeled and positioned_

* Like the immediate feedback of the tag updates [Ben H.]
* Not sure about having two ways to enter a tag - gives me options but I'm not sure - also it seems to remove options from the drop down in a way I don't understand [Dennise O.]

h2. View story / bug

* I'm confused why viewing a card doesn't show the same things as edit / or doesn't lay them out in the same way [Lindsay R.]  [Josh P.]  [Mike Mc.]  [Ben H.]  [Dennise O.]

bq. _See story #727 - The layout / presentation of the 'edit' and 'view' pages for stories / bugs / etc. should be consistent_

* If I make a change in the view mode - is it saved? [Ben H.]
* Link is to 'All' cards - but I came from 'Bugs' - I'd expect to go back there [Dennise O.]

h2. Comment

* Box for the comment is large - very large in comparison to the comment text [Ben H.]

bq. _See story #727 - The layout / presentation of the 'edit' and 'view' pages for stories / bugs / etc. should be consistent_

* I like the fact it adds who made the comment - means I don't have to [Ben H.]

h2. Wiki

* Have used very few wikis [Lindsay R.]
* Expected the 'Show preview' button to take me to a preview page - didn't realize it was below [Lindsay R.]  [Shelley B.]  [Mike Mc.]  [Ben H.]
* What's 'Live preview'? Not clear [Mike Mc.]

bq. _Story created #732 - Rework phrasing / positioning of preview button on Wiki page_

* Would very much prefer WYSIWYG - have exposure to mark-up via Confluence but don't like it [Shelley B.]  [Josh P.]  [Mike Mc.]
* Am comfortable with mark-up [Ben H.]

bq. _Story created #733 - Ability to edit content via a WYSIWYG editor_

* Will we get templates - it would be good to have templates for the wiki content [Shelley B.]  [Josh P.]  [Ben H.]  [Dennise O.]

bq. _There are multiple stories addressing the creation of templates (scaffold) to help ensure users have a good set of defaults out of the box_

* No feedback on the link to indicate that it's an uncreated page - should be [Jason Y.]

bq. _Story created #734 - Provide visual feedback on the Wiki for links that will add a new page_

* Wiki page history wasn't obvious - went to the history tab first  - in page one looked like just another link [Jason Y.]

bq. _Location of history and comments is being addressed now by story #616 - Rework card view/edit to have discussion and history in the side panel_

* History without the ability to diff is useless to me [Jason Y.]

bq. _Already captured as story #298 - scheduled for release 1.1_

* Am used to having a 'recent pages' area showing pages I've just been to - that would be nice [Ben H.]

bq. _See story #701 -  	Ability to more effectively navigate the Wiki_

* Don't like 'Publish' feels very final - prefer something consistent with other areas, e.g. 'Save' [Ben H.]

bq. _See bug #724 - Action buttons / links should be consistently labeled and positioned_

h2. Search

* Expect this to be grouped by type [Lindsay R.]

bq. _Group by functionality for search is in play but not for R1_

* Weird that it's placed out there [Josh P.]
* Good that it searches all text, including the tags, but it should give preference to title, description and comments text - e.g. I'd be annoyed if a card with text matched in the tag was listed before a card with a match in the title. Tag hits could be listed separately / grouped [Josh P.]

h2. Statistics

* Would like a way to reference these stats (total number of x, total story points) rather than having to re-key (e.g. like the 'special' mark-up you get in Confluence - would be great to have some kind of 'Add this' (to my wiki page) capability [Shelley B.]  [Jason Y.]  [Dennise O.]
* Language should be consistent - what does cards mean in the context of the stories list vs. the bugs list [Josh P.]
* This is key for me - for project managers - being able to capture stats about the status of the cards - and how that's changed over a particular time period - I'd want these on an overview page automatically [Mike Mc.]

bq. _Certain information is going to be available using a simple reference - this is being addressed as part of the template (scaffold work) and in particular the work on dashboards - #702_

* Was expecting statistics information to be in the sidebar even when I was in the wiki [Shelley B.]

bq. _Unsure - content of sidebar will be reviewed as part of story #722 - Sidebar needs to be cleaned up with clearer headings and more intuitive grouping / ordering of content_

h2. History

* Assume history tab would contain all revisions to the project - would think it's the same as history at the bottom of the page [Lindsay R.]
* Confusing behavior from page title links in history - the first one doesn't link but the rest do - this changes when you follow the link [Ben H.]

bq. _See story #615 - rework the History events and its links_

* Very much like having the audit trail [Ben H.]

h2. Grid view

* Colour the cards to indicate type [Josh P.]
* Inline editing on the cards in the grid view would be great - c.f. Card Meeting by James Shaw - http://www.cardmeeting.com/ [Jason Y.]
* Love the grid view [Mike Mc.]
* Nice [Ben H.]

h2. General

* Assume there's something different about 'Project admin' because it's off to the right, would expect overall project settings to be there [Lindsay R.]

bq. _Yes - pretty much spot on_

* Why are some things buttons and some things links? Assume a link will take me somewhere [Lindsay R.]

bq. _We're moving to a consistent approach on this_

* Why are there two 'new card' links? [Lindsay R.]

bq. _As we move to a consistent positioning for actions we've some that are doubled up - these will go_

* Why do we sometimes talk about stories and bugs and sometimes about cards? [Lindsay R.]

bq. _Again we're in transition - likely we'll remove all references to 'cards'_

* Could there be a drop-down to other projects in the header? [Lindsay R.]

bq. _Possibility - likely the app will have a single project focus initially so this may not be so important_

* Presentation is good [Shelley B.]  [Mike Mc.]
* Found the tags confusing [Shelley B.]  [Mike Mc.]

bq. _Understood - we're beginning to address this with a different approach to bulk editing and an improved tag editor - see story #725 (Ability to change the properties of multiple (bulk) stories / bugs via an iTunes like bulk edit screen), #173 (Build a better tag editor) and #718 (Revise table header to make bulk actions on items more intuitive)_

* Wasn't clear what the 'Overview' was [Shelley B.]
* Switching between areas was confusing [Shelley B.]

bq. _Hopefully addressed by improvements to navigation and the more intuitive matching of tabs to editing screens_

* Templates / scaffold would be extremely useful [Shelley B.]  [Josh P.]  [Mike Mc.]
* Templates could be packaged and shared with others [Josh P.]

bq. _Templates (scaffolds) are being addressed right away - see story #670 - Create project from template_

* With long lists it can be good to duplicate the action buttons at the top and bottom [Josh P.]

bq. _Agreed - should consider depending on our pagination approach (i.e. will we allow very long pages)

* Actions should be consistently placed at the top (and may be bottom - see above) and be context sensitive [Josh P.]

bq. _See bug #724 - Action buttons / links should be consistently labeled and positioned_ 

* Hover tips to give more information [Josh P.]
* In places (e.g. bulk edit) the app took a noticeable time to respond - performance must be a priority [Jason Y.]  [Ben H.]
* Speed of entry - for example enhanced by keyboard shortcuts - is really important [Jason Y.]  [Ben H.]
* Consistency in language and behavior (cards -> stories)  [Josh P.]  [Mike Mc.]  [Dennise O.]

bq. _Agreed see at least bug #724 - Action buttons / links should be consistently labeled and positioned_ 

* Don't like the Javascript pop-up confirmations - my browser would probably block them and they don't sit well with the web2.0 feel [Jason Y.]

bq. _Unlikely in the extreme that these will remain_

* Language such as 'Wiki' and 'Tag' isn't likely to play so well with the majority of less technical users [Jason Y.]  [Mike Mc.]  [Ben H.]

bq. _Intention to be as jargon free as possible_

* Make it as pictorial as possible - more icons associated with links [Mike Mc.]  [Dennise O.]

bq. _Icons and other visual representations of data are being introduced_

* Less reading - as little as possible [Mike Mc.]
* There's no help [Ben H.]

bq. _Story created #735 - Create help text for the application_

* Did get frustrated - though I get frustrated with Excel too [Ben H.]
* Being used to Excel I'd like the benefits of the tracking and the integration but with the inline entry grid I know [Dennise O.]
HERE

run
