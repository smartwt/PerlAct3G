#!/usr/bin/perl
package Class_vmstatResult;
require "./lib/mimew.pl";

use strict;
use warnings;
use Archive::Zip;
use NET::SMTP;
use utf8;
use Encode;
use MIME::Base64;
use File::Basename;

my $HOSTFILE = "hostlist";
my $ACCOUNT = "swing";
my $PASSWORD ="swinguser"; 

# 宛先の宛名とメールアドレスを設定する。
#my $mail_to = 's-matsumoto@dn.jp.nec.com, ueda-kouji@sa.nesic.com,k-shiraishi@sa.nesic.com,y-satou@z6.nesic.com';
my $mail_to = 'y-satou@z6.nesic.com';
#複数送信の時は配列に格納
my @mailAddressArray = split(/,/,$mail_to);

# メール送信に使うSMTPサーバーと、ポート番号、送信者のドメインを設定する。
my $smtp_server = 'smtp';
my $smtp_port = '25';
my $smtp_helo = 'actwatch.com';

# 送信者の名前とメールアドレス
my $mail_from_name = 'ACTWATCH3G vmstat出力まとめ';
my $mail_from = '192.168.41.214';
# メールタイトル
my $subject = 'リソース(/tmp/resource)';


#ZIPファイル名
my $zip_file = 'vmstatfile.zip';

#コンストラクタ
sub new {
	
	bless{
		txtfilearray => [],
	},shift;
}

#圧縮対象のファイルを配列に格納
sub filearray {
	my $vmstatResult = shift;
	if (@_) { 
		push @{ $vmstatResult->{txtfilearray} }, @_  
	}

}
#配列を返す
sub filearray_getter_all {
	my $vmstatResult = shift;
	return $vmstatResult->{txtfilearray};
}

#vmstatの結果を取得する
sub getVmstatLog{
	my $vmstatResult = shift;
	my $hostname = shift;
	
	#現在日時を取得
	my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = localtime(time);  
	my $yyyymmdd = sprintf("%04d%02d%02d", $year + 1900, $mon + 1, $mday);  
	#コマンド取得
	#小文字を大文字に変換uc
	my $filehostname = $hostname;
	$filehostname =~ tr/a-z/A-Z/;
	my $GET_RESOURCE_COMM = "cat /tmp/resouce/".$filehostname."_resouce.log > ";
	my $task = "lib\\Plink.exe -pw $PASSWORD -l $ACCOUNT $hostname $GET_RESOURCE_COMM $hostname"."_resource_".$yyyymmdd.".log";
	
	#コマンド実行
	my $result = qx ($task);
	if($?){
		return "ERROR  ".$!;
	}else{
		#配列に格納
		my $fname = $hostname."_resource_".$yyyymmdd.".log";
		$vmstatResult->filearray ($fname);
	}
}
#取得したファイルをzip化
sub getZipfile{
	my $vmstatResult = shift;
	
	my $zip = Archive::Zip->new();
	foreach my $outfile (@{$vmstatResult->filearray_getter_all}){
	
		$zip->addFile( $outfile );
		$zip->writeToFileNamed($zip_file);
	} 
	$vmstatResult->getZipMail($zip_file,"");
}
#zipファイルをメール送信
sub getZipMail{
	
	my $vmstatResult = shift;
	# バウンダリ
	my $bound = 'wq5se3d1ew';

	my ($filelist,$textline) = @_;

	push(my  @flist, $filelist);
	push(my  @text, $textline);


	# 添付ファイルをBase64エンコードする
	my $base64_data;
	my @base64_data_array;
		
	for( my $i=0; $i <= $#flist; $i++){
		if ( $flist[$i] ){
			if(!open FF,$flist[$i]){
				#logger ("Cannot Open $flist[$i] \n");
				unshift (@text,"Cannot Open $flist[$i]"."\r\n\r\n");
			}else{

				$base64_data = join('',<FF>);
				close(FF);

				$base64_data = main'bodyencode($base64_data,"b64");
				$base64_data .= main'benflush("b64");
				push(@base64_data_array,$base64_data);
			}
		}
	}
	
	# 送信者名、送信者のメールアドレスを、
	# From: 送信者名 <送信者メールアドレス> 形式へ変換する。
	my $from = make_name_addr('From:',$mail_from_name,$mail_from);

	# 宛名、宛先のメールアドレスを、
	#my $to = make_name_addr('To:',$mail_to_name,$mail_to);
	my $to = "To: ".trim($mail_to)."\n";

	# ヘッダ
	my $smtp = Net::SMTP->new($smtp_server,Port=>$smtp_port,Hello=>$smtp_helo) or die ("SMTP SERVER CONNECT ERROR $!" );
	#送信元の指定
	$smtp->mail($mail_from) or die ("MAIL SENDER ERROR $!" );
	
	#宛先の指定
	$smtp->to(@mailAddressArray);
	my $date = &date;
	$smtp->data();
	$smtp->datasend("MIME-Version: 1.0\n");
	$smtp->datasend("Content-Type: Multipart/Mixed; boundary=\"$bound\"\n");
	$smtp->datasend("Content-Transfer-Encoding:Base64\n");
	$smtp->datasend("Date:$date\n");
	$smtp->datasend("$from");
	$smtp->datasend("$to");
	# $smtp->datasend("Cc:$cc\n");
	$smtp->datasend("Subject: ".encode('MIME-Header',"【メモリ】".$subject)."\n");
	$smtp->datasend("--$bound\n");
	$smtp->datasend("Content-Type: text/plain; charset=\"UTF-8\"\n\n");
	#本文
	$smtp->datasend(join('',@text));
	
	# 添付
	for( my $i=0; $i <= $#flist; $i++){
		my $filenmame = $flist[$i];
		if ( $base64_data_array[$i] ){ 
			$smtp->datasend("--$bound\n"); 
			$smtp->datasend("Content-Transfer-Encoding: BASE64\n");
			$smtp->datasend("Content-Type:application/octet-stream; name=$filenmame\"\n\n");
			$smtp->datasend("$base64_data_array[$i]\n"); 
			#$smtp->datasend("--$bound\n");
		}
	}
	# データの終わり、メール送信
	$smtp->dataend();
	#SMTP接続の終了
	$smtp->quit;

}
sub date { 
	$ENV{'TZ'} = "JST-9";
	my ($sec,$min,$hour,$mday,$mon,$year,$wday) = localtime(time);
	my @week = ('Sun','Mon','Tue','Wed','Thu','Fri','Sat');
	my @month = ('Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'); 
	my $d = sprintf("%s, %d %s %04d %02d:%02d:%02d +0900 (JST)", $week[$wday],$mday,$month[$mon],$year+1900,$hour,$min,$sec);
	return $d;
}
# 名前とメールアドレスから、name_addr形式のフォーマットを作るサブルーチン。
sub make_name_addr {
	# 引数を受け取る。
	my ($mail_direction,$mail_name,$mail_address) = @_;
	# 末尾にスペースを追加して"From: "または "To: "を作る。
	my $name_addr = $mail_direction.' ';

	# 名前(送信者名または宛名)が設定されているか調べる。
	if ($mail_name ne "") {
		# 名前が設定されていたら、
		# 名前をMIMEエンコードして、末尾にスペースを追加する。
		$name_addr .= encode('MIME-Header',$mail_name).' ';
	}
	# メールアドレスを追加する。
	return ($name_addr .= '<'.$mail_address.">\n");
}
sub trim {
	my $val = shift;
	$val =~ s/^ *(.*?) *$/$1/;
	return $val;
}

1;


my $vmstatResult = Class_vmstatResult->new();
open(my $fh, "<", $HOSTFILE)
  or die ("Cannot open $HOSTFILE: $! \n");

while(my $line = readline $fh){ 
	# chomp関数で、改行を取り除く
	chomp $line;
	#コメント　空文字は次へ
	if ($line =~ /^#/ or $line eq ''){
		next;
	}
	$line = trim($line);

	print $line."\r\n";

	#ファイルに書いてあるホストログを取得
	$vmstatResult->getVmstatLog($line);

}
#ファイルをzipファイルに圧縮してメール送信
$vmstatResult->getZipfile;

#終わったらファイルを削除
foreach my $deletefile (@{$vmstatResult->filearray_getter_all}){
	unlink($deletefile);

}
unlink($zip_file);
