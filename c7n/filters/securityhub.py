# Copyright 2019 Capital One Services, LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
from __future__ import absolute_import, division, print_function, unicode_literals
import json

from c7n.utils import local_session, type_schema
from .core import Filter
from c7n.manager import resources


class SecurityHubFindingFilter(Filter):
    """Check if there are Security Hub Findings related to the resources
    """
    schema = type_schema(
        'finding',
        filter_json={'type': 'string'}
    )
    permissions = ('securityhub:GetFindings',)

    def process(self, resources, event=None):
        client = local_session(self.manager.session_factory).client(
            'securityhub', region_name='us-east-1')

        found = []
        f = self.get_filter_parameters()

        for resource in resources:
            f['ResourceId'] = [
                {
                    "Value": self.manager.generate_arn(resource[self.manager.get_model().id]),  # TODO: test if this will this fail for app-elb?
                    "Comparison": "EQUALS",
                }
            ]

            self.log.debug("filter=%s", f)
            findings = client.get_findings(Filters=f).get("Findings")

            if len(findings) > 0:
                found.append(resource)

        return found

    def get_filter_parameters(self):
        f = {}
        if self.data.get('filter_json'):
            f = json.loads(self.data.get('filter_json'))
        return f

    @classmethod
    def register_resources(klass, registry, resource_class):
        """ meta model subscriber on resource registration.

        SecurityHub Findings Filter
        """
        for rtype, resource_manager in registry.items():
            if 'post-finding' in resource_manager.action_registry:
                continue
            resource_class.filter_registry.register('finding', klass)


resources.subscribe(resources.EVENT_REGISTER, SecurityHubFindingFilter.register_resources)
