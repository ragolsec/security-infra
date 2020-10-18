#!/usr/bin/python3
yaml_file = open("/opt/security-infra/playbooks/install-debs.yml", "w+")
input_file = open("/opt/security-infra/tools/packages-to-install.txt", "r")

input_data = input_file.readlines()
input_file.close()
yaml_file.write("---\n")
yaml_file.write("- hosts: scanners\n")
yaml_file.write("  become: yes\n")
yaml_file.write("  tasks:\n")

for line in input_data:
    yaml_file.write("    - name: install " + line)
    yaml_file.write("      apt:\n")
    yaml_file.write("        name: " + line[:-1] + "\n")
    yaml_file.write("        state: latest\n")
yaml_file.write ("    - name: Install Yarn\n")
yaml_file.write ("      script:\n")
yaml_file.write ("        cmd: ../tools/install-yarn.sh\n")

yaml_file.close()
