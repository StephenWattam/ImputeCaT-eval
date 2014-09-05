#!/usr/bin/env php
<?php

// Include the text statistics class
require_once dirname( __FILE__ ) . DIRECTORY_SEPARATOR . 'TextStatistics.php';


if($argc < 2){

    print("USAGE: ./script.php SCORETYPE FILENAME\n");
    print("\n");
    print("Score types:\n");
    print("  flesch_kincaid_reading_ease\n");
    print("  flesch_kincaid_grade_level\n");
    print("  gunning_fog_score\n");
    print("  coleman_liau_index\n");
    print("  smog_index\n");
    print("  automated_readability_index\n");
    exit(1);
}

$type       = $argv[1];
$filename   = $argv[2];

# Read the input file
$myfile = fopen($filename, "r");
$str = fread($myfile, filesize($filename));
fclose($myfile);

# Construct a text statistics object
$ts = new TextStatistics();

$score = null;
switch($type){
    case 'flesch_kincaid_reading_ease':
        $score = $ts->flesch_kincaid_reading_ease($str);
        break;
    case 'flesch_kincaid_grade_level':
        $score = $ts->flesch_kincaid_grade_level($str);
        break;
    case 'gunning_fog_score':
        $score = $ts->gunning_fog_score($str);
        break;
    case 'coleman_liau_index':
        $score = $ts->coleman_liau_index($str);
        break;
    case 'smog_index':
        $score = $ts->smog_index($str);
        break;
    case 'automated_readability_index':
        $score = $ts->automated_readability_index($str);
        break;
    default:
        print("No such reading ease score");
        exit(1);
}


print($score . "\n");

?>
