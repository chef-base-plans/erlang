title 'Tests to confirm erlang works as expected'

plan_origin = ENV['HAB_ORIGIN']
plan_name = input('plan_name', value: 'erlang')

control 'core-plans-erlang-works' do
  impact 1.0
  title 'Ensure erlang works as expected'
  desc '
  Verify erlang by ensuring that
  (1) its installation directory exists 
  (2) erl returns the expected version
  (3) all other binaries, except for "escript" return expected "help" usage info
  (4) escript successfully runs an erlang "Hello World!" script

  NOTE: testing all these binaries can be tricky: some use "--help" others
  use "-help"; some return output to stdout, other to stderr; some return "Usage:..."
  others return "usage:..."  The outcome is that no one standard test pattern can be 
  used for all.  escript must reference an actual file; the normal linux <(..) re-direction
  does not work.
  '
  
  plan_installation_directory = command("hab pkg path #{plan_origin}/#{plan_name}")
  describe plan_installation_directory do
    its('exit_status') { should eq 0 }
    its('stdout') { should_not be_empty }
    its('stderr') { should be_empty }
  end
  
  plan_pkg_version = plan_installation_directory.stdout.split("/")[5]
  full_suite = {
    "ct_run" => {
      command_output_pattern: /ct_run -dir TestDir1 TestDir2/,
      exit_pattern: /^[0]$/,
    },
    "dialyzer" => {
      command_suffix: "--help",
      exit_pattern: /^[0]$/,
    },
    "epmd" => {
      io: "stderr", 
    },
    "erl" => {
      command_suffix: "-eval '{ok, Version} = file:read_file(filename:join([code:root_dir(), \"releases\", erlang:system_info(otp_release), \"OTP_VERSION\"])), io:fwrite(Version), halt().' -noshell",
      command_output_pattern: /#{plan_pkg_version}/,
      exit_pattern: /^[0]$/,
    },
    "erlc" => {
      io: "stderr", 
    },
    "escript" => {
      command_suffix: "",
      command_output_pattern: /Hello, World!/, 
      exit_pattern: /^[0]$/,
      script: <<~END
        #!/usr/bin/env escript
        -export([main/1]).
        main([]) -> io:format("Hello, World!~n").
      END
    },
    "run_erl" => {
      io: "stderr",
    },
    "to_erl" => {
      io: "stderr",
    },
    "typer" => {
      command_suffix: "--help",
      exit_pattern: /^[0]$/,
    },
  }
  
  # Use the following to pull out a subset of the above and test progressiveluy
  subset = full_suite.select { |key, value| key.to_s.match(/^[a-z].*$/) }
  
  # over-ride the defaults below with (command_suffix:, io:, etc)
  subset.each do |binary_name, value|
    command_suffix = value[:command_suffix] || "-help"
    command_output_pattern = value[:command_output_pattern] || /[uU]sage:.+#{binary_name}/ 
    exit_pattern = value[:exit_pattern] || /^[^0]$/ # use /^[^0]$/ for non-zero exit status
    io = value[:io] || "stdout"
    command_full_path = File.join(plan_installation_directory.stdout.strip, "bin", binary_name)
    script = value[:script]

    command_statement = "#{command_full_path} #{command_suffix}"
    actual_command_under_test = command("#{command_statement}")
    if(script)
      Tempfile.open('foo') do |f|
        f << script
        command_full_path = File.join(plan_installation_directory.stdout.strip, "bin", "escript")
        actual_command_under_test = command("#{command_statement} #{f.path}")
      end
    end

    describe actual_command_under_test do
      its('exit_status') { should cmp exit_pattern }
      its(io) { should match command_output_pattern }
    end


  end

end