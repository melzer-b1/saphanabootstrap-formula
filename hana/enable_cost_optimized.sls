{%- from "hana/map.jinja" import hana with context -%}
{%- from 'hana/macros/get_hana_client_path.sls' import get_hana_client_path with context %}

{% set host = grains['host'] %}

{% for node in hana.nodes %}
{%- set hana_client_path = get_hana_client_path(hana, node) %}
{% if node.host == host and node.scenario_type is defined and node.scenario_type.lower() == 'cost-optimized' and node.cost_optimized_parameters is defined%}

reduce_memory_resources_{{  node.host+node.sid }}:
  hana.memory_resources_updated:
    - name: {{  node.host }}
    - global_allocation_limit: {{ node.cost_optimized_parameters.global_allocation_limit }}
    - preload_column_tables: {{ node.cost_optimized_parameters.preload_column_tables }}
    - user_name: SYSTEM
    {% if node.install.system_user_password is defined %}
    - user_password: {{ node.install.system_user_password }}
    {% endif %}
    - sid: {{  node.sid }}
    - inst: {{  node.instance }}
    - password: {{  node.password }}
    - require:
      - hana_install_{{ node.host+node.sid }}

{% if node.host == host and node.secondary is defined %}

setup_srHook_directory:
  file.directory:
    - name: /hana/shared/srHook
    - user: {{ node.sid.lower() }}adm
    - group: sapsys
    - mode: 755
    - makedirs: True
    - require:
      - reduce_memory_resources_{{ node.host+node.sid }}

install_srCostOptMemConfig_hook:
  file.managed:
    - source: salt://hana/templates/srCostOptMemConfig_hook.j2
    - name: /hana/shared/srHook/srCostOptMemConfig.py
    - user: {{ node.sid.lower() }}adm
    - group: sapsys
    - mode: 755
    - template: jinja
    - require:
      - setup_srHook_directory

{% set platform = grains['cpuarch'].upper() %}
{% if platform not in ['X86_64', 'PPC64LE'] %}
failure:
  test.fail_with_changes:
    - name: 'not supported platform. only x86_64 and ppc64le are supported'
    - failhard: True
{% endif %}

configure_ha_dr_provider_srCostOptMemConfig:
  ini.options_present:
    - name:  /hana/shared/{{ node.sid.upper() }}/global/hdb/custom/config/global.ini
    - separator: '='
    - strict: False # do not touch rest of file
    - sections:
        ha_dr_provider_srCostOptMemConfig:
          provider: 'srCostOptMemConfig'
          path: '/hana/shared/srHook'
          execution_order: '2'
    - require:
      - reduce_memory_resources_{{ node.host+node.sid }}
      - setup_srHook_directory
      - install_srCostOptMemConfig_hook
{% endif %}
{% endif %}
{% endfor %}
