webmachine_splunk
=================

Splunk interface for webmachine

This can be used to allow webmachine / mochiweb to log data to splunk
instead of a traditional log file. you will need to add configurations
to your environment like this with your token and project id from
splunk.

~~~~~~~~~~~~~~~~~~~~~
  {splunk, [
	   {access_token, <<"****************************************">>},
	   {project_id, <<"****************************************">>}
	  ]},
~~~~~~~~~~~~~~~~~~~~~
