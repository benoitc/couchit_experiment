## Licensed under the Apache License, Version 2.0 (the "License"); you may not
## use this file except in compliance with the License.  You may obtain a copy
## of the License at
##
##   http://www.apache.org/licenses/LICENSE-2.0
##
## Unless required by applicable law or agreed to in writing, software
## distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
## WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.  See the
## License for the specific language governing permissions and limitations under
## the License.

couchitebindir = $(localerlanglibdir)/couchit/ebin

couchit_file_collection = \
	couchit_httpd.erl 

couchitebin_make_generated_file_list = \
	couchit_httpd.beam

couchitebin_DATA = \
	$(couchitebin_make_generated_file_list)

EXTRA_DIST = \
	$(couchit_file_collection)

CLEANFILES = \
    $(couchitebin_make_generated_file_list)

%.beam: %.erl
	$(ERLC) $(ERLC_FLAGS) $<
