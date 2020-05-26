
Configure background jobs by mingle.properties
===============================

Turn off all background jobs, no matter what's background job works count settings.
-------------------------------

    -Dmingle.noBackgroundJob=true

Add more background jobs for specific task
-------------------------------

Increase Mingle full text search indexing job workers to 5:

    -Dmingle.full_text_search_indexing_processors.workerCount=5

Technically, it means we'll start 5 threads, each of which will run full text search indexing task.
Here is a all task names that can increase worker count:

    card_importing_preview
    link_cards_and_murmurs
    full_text_search_indexing_processors
    history_generation
    compute_aggregates
    rebuild_objective_snapshots

Set the value to 0 to turn the task off, for example:

    -Dmingle.full_text_search_indexing_processors.workerCount=0

By default, all tasks have one worker.
