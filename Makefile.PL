use 5.006001;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'		=> 'Log::Dispatch::File::Rolling',
    'VERSION_FROM'	=> 'Rolling.pm', # finds $VERSION
    'PREREQ_PM'		=> {
    	'Log::Log4perl' => '0.32',
    	'Log::Dispatch' => '2.06',
    }, # e.g., Module::Name => 1.1
    ($] >= 5.005 ?    ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM => 'Rolling.pm', # retrieve abstract from module
       AUTHOR     => 'M. Jacob <jacob@j-e-b.net>') : ()),
);
