require File.expand_path('../../../spec_helper', __FILE__)

describe Pod::Command::Spec do
  extend SpecHelper::Command
  extend SpecHelper::TemporaryDirectory

  it "complains for wrong parameters" do
    lambda { run_command('spec') }.should.raise Pod::Command::Help
    lambda { run_command('spec', 'create') }.should.raise Pod::Command::Help
    lambda { run_command('spec', '--create') }.should.raise Pod::Command::Help
    lambda { run_command('spec', 'NAME') }.should.raise Pod::Command::Help
    lambda { run_command('spec', 'createa') }.should.raise Pod::Command::Help
    lambda { run_command('lint', 'agument1', '2') }.should.raise Pod::Command::Help
  end
end

describe "Pod::Command::Spec#create" do
  extend SpecHelper::Command
  extend SpecHelper::Github
  extend SpecHelper::TemporaryDirectory
  extend SpecHelper::Git

  it "creates a new podspec stub file" do
    run_command('spec', 'create', 'Bananas')
    path = temporary_directory + 'Bananas.podspec'
    spec = Pod::Specification.from_file(path)
    spec.name.should               == 'Bananas'
    spec.license.should            == { :type => "MIT", :file => "LICENSE" }
    spec.version.should            == Pod::Version.new('0.0.1')
    spec.summary.should            == 'A short description of Bananas.'
    spec.homepage.should           == 'http://EXAMPLE/Bananas'
    spec.authors.should            == { `git config --get user.name`.strip => `git config --get user.email`.strip}
    spec.source.should             == { :git => 'http://EXAMPLE/Bananas.git', :tag => '0.0.1' }
    spec.description.should        == 'An optional longer description of Bananas.'
    spec.source_files[:ios].should == ['Classes', 'Classes/**/*.{h,m}']
  end

  it "correctly creates a podspec from github" do
    expect_github_repo_request
    expect_github_user_request
    expect_github_tags_request
    run_command('spec', 'create', 'https://github.com/lukeredpath/libPusher.git')
    path = temporary_directory + 'libPusher.podspec'
    spec = Pod::Specification.from_file(path)
    spec.name.should     == 'libPusher'
    spec.license.should  == { :type => "MIT", :file => "LICENSE" }
    spec.version.should  == Pod::Version.new('1.3')
    spec.summary.should  == 'An Objective-C interface to Pusher (pusherapp.com)'
    spec.homepage.should == 'https://github.com/lukeredpath/libPusher'
    spec.authors.should  == {"Luke Redpath"=>"luke@lukeredpath.co.uk"}
    spec.source.should   == { :git => 'https://github.com/lukeredpath/libPusher.git', :tag => 'v1.3' }
  end

  it "accepts a name when creating a podspec form github" do
    expect_github_repo_request
    expect_github_user_request
    expect_github_tags_request
    run_command('spec', 'create', 'other_name', 'https://github.com/lukeredpath/libPusher.git')
    path = temporary_directory + 'other_name.podspec'
    spec = Pod::Specification.from_file(path)
    spec.name.should     == 'other_name'
    spec.license.should  == { :type => "MIT", :file => "LICENSE" }
    spec.version.should  == Pod::Version.new('1.3')
    spec.summary.should  == 'An Objective-C interface to Pusher (pusherapp.com)'
    spec.homepage.should == 'https://github.com/lukeredpath/libPusher'
    spec.authors.should  == {"Luke Redpath"=>"luke@lukeredpath.co.uk"}
    spec.source.should   == { :git => 'https://github.com/lukeredpath/libPusher.git', :tag => 'v1.3' }
  end

  it "correctly suggests the head commit if a suitable tag is not available on github" do
    expect_github_repo_request
    expect_github_user_request
    expect_github_tags_request([{"name" => "experiment"}])
    expect_github_branches_request
    run_command('spec', 'create', 'https://github.com/lukeredpath/libPusher.git')
    path = temporary_directory + 'libPusher.podspec'
    spec = Pod::Specification.from_file(path)
    spec.version.should == Pod::Version.new('0.0.1')
    spec.source.should  == { :git => 'https://github.com/lukeredpath/libPusher.git', :commit => '5f482b0693ac2ac1ad85d1aabc27ec7547cc0bc7' }
  end

  it "provides a markdown template if a github repo doesn't have semantic version tags" do
    expect_github_repo_request
    expect_github_user_request
    expect_github_tags_request([{"name" => "experiment"}])
    expect_github_branches_request
    output = run_command('spec', 'create', 'https://github.com/lukeredpath/libPusher.git')
    output.should.include 'MARKDOWN TEMPLATE'
    output.should.include 'Please add semantic version tags'
  end
end

describe "Pod::Command::Spec#lint" do
  extend SpecHelper::Command
  extend SpecHelper::TemporaryDirectory
  extend SpecHelper::Git

  before do
    config.repos_dir = fixture('spec-repos')
  end

  after do
    config.repos_dir = tmp_repos_path
  end

  it "lints a repo" do
    # The fixture has an error due to a name mismatch
    cmd = command('spec', 'lint', 'master')
    lambda { cmd.run }.should.raise Pod::Informative
    cmd.output.should.include "InAppSettingKit (0.0.1)\n    - ERROR | The name of the spec should match the name of the file"
    cmd.output.should.include "WARN"
  end

  it "complains if no repo name or url are provided and there a no specs in the current working directory" do
    Dir.chdir(fixture('spec-repos') + 'master/JSONKit/') do
      lambda { command('spec', 'lint').run }.should.raise Pod::Informative
    end
  end

  it "lints the current working directory" do
    Dir.chdir(fixture('spec-repos') + 'master/JSONKit/1.4/') do
      output = command('spec', 'lint', '--quick', '--only-errors').run
      output.should.include "passed validation"
    end
  end

  it "lints a givent podspec" do
    spec_file = fixture('spec-repos') + 'master/JSONKit/1.4/JSONKit.podspec'
    cmd = command('spec', 'lint', '--quick', spec_file.to_s)
    lambda { cmd.run }.should.raise Pod::Informative
    cmd.output.should.include "Missing license[:file] or [:text]"
  end

  it "respects the -only--errors option" do
    spec_file = fixture('spec-repos') + 'master/JSONKit/1.4/JSONKit.podspec'
    cmd = command('spec', 'lint', '--quick', '--only-errors', spec_file.to_s)
    lambda { cmd.run }.should.not.raise
    cmd.output.should.include "Missing license[:file] or [:text]"
  end
end
