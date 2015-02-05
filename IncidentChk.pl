#!/usr/bin/perl -w
use strict;
use warnings;
use NET::SMTP;
use utf8;
use Encode;
use MIME::Base64;
use File::Basename;


require "./lib/mimew.pl";
require "./lib/logger.pl";

#インシデント対応履歴数閾値
my $Incidentbar = "50000";

#統合サーバ(ホスト名 or IPアドレス)
my @pesisList = ('pesis11','pesis12');
 
# 宛先の宛名とメールアドレスを設定する。
my $mail_to = '';
#my $mail_to = '';
#複数送信の時は配列に格納
my @mailAddressArray = split(/,/,$mail_to);

# メール送信に使うSMTPサーバーと、ポート番号、送信者のドメインを設定する。
my $smtp_server = 'smtp';
my $smtp_port = '25';
my $smtp_helo = 'actwatch.com';

# 送信者の名前とメールアドレス
my $mail_from_name = 'ACTWATCH3G IncidentHistory.sh';
#my $mail_from = 'mp1@ab.actwatch.net';
my $mail_from = '192.168.41.214';


# メールタイトル
my $subject = '【インシデント】対応履歴の閾値オーバー';

my $ACCOUNT="swing";
my $PASSWORD="swinguser";

my $SYSSWITCH_COMM ="sudo /home/swing/sysswitchctl";
my $INCIDENTHISTORY_COMM ="sudo /home/swing/IncidentHistory.sh";

#一時ファイル
my $outputFname = "tmp_outputIncident";

my @text = ();
my @tmptext = ();
my @flist = ();

#今日の日付を取得  
my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = localtime(time);  
my $yyyymmdd = sprintf("%04d%02d%02d", $year + 1900, $mon + 1, $mday);  

#統合サーバ数分ループ
for(my $i=0;$i < @pesisList; $i++ ){ 
	# chomp関数で、改行を取り除く
	chomp $pesisList[$i];
	
	#コメント　空文字は次へ
	if ( $pesisList[$i] eq ''){
		next;
	}
	my $host = trim($pesisList[$i]);

	my $task = "lib\\Plink.exe -auto_store_key_in_cache -pw $PASSWORD -l $ACCOUNT $host $SYSSWITCH_COMM ";
	my $shstlist = qx ($task);
	if($?){
		logger ($host." Command Error \"$SYSSWITCH_COMM\" $!");
		push (@text," Command Error \"$SYSSWITCH_COMM\" $! \r\n");
	}
	
	#現用系の時のみ
	if ($shstlist =~/ACT/){

		#チェックシェル実行
		my $task = "lib\\Plink.exe -auto_store_key_in_cache -pw $PASSWORD -l $ACCOUNT $host $INCIDENTHISTORY_COMM $Incidentbar > $outputFname";
		my $shstlist = qx ($task);
		my $audob = Class_IncidentHistory->new();
		$audob->infile("$outputFname");			
		my @tmptext = $audob->getIncidentHistory;

		if (defined($audob->errorMsg) ){
			logger ($audob->errorMsg);
		}
		elsif ($#tmptext > 1 ){
			push(@tmptext,"\n");
			push (@text,@tmptext);

			#メールの送信
			&mailSend(\@flist,\@text);
		}
	}
}

#一時ファイルの削除
unlink $outputFname;

sub mailSend{

	# バウンダリ
	my $bound = 'wq5se3d1ew';

	my ($filelist,$textad) = @_;
	my @flist = @{$filelist};
	my @text = @{$textad};
	
	
	# 添付ファイルをBase64エンコードする
	my $base64_data;
	my @base64_data_array;
		
	for( my $i=0; $i <= $#flist; $i++){
		
		if ( $flist[$i] ){
			if(!open FF,$flist[$i]){
				logger ("Cannot Open $flist[$i] \n");
				unshift (@text,"Cannot Open $flist[$i]"."\r\n\r\n");
			}else{
				
				$base64_data = join('',<FF>);
				close(FF);
				$base64_data = &bodyencode($base64_data,"b64");
				$base64_data .= &benflush("b64");
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
	my $smtp = Net::SMTP->new($smtp_server,Port=>$smtp_port,Hello=>$smtp_helo) or die logger("SMTP SERVER CONNECT ERROR $!" );
	#送信元の指定
	$smtp->mail($mail_from) or die logger("MAIL SENDER ERROR $!" );
	
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
	$smtp->datasend("Subject: ".encode('MIME-Header',"$subject 閾値 $Incidentbar")."\n");
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
	logger ("IncidentChk.pl メール送信完了");
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
sub date { 
	$ENV{'TZ'} = "JST-9";
	my ($sec,$min,$hour,$mday,$mon,$year,$wday) = localtime(time);
	my @week = ('Sun','Mon','Tue','Wed','Thu','Fri','Sat');
	my @month = ('Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'); 
	my $d = sprintf("%s, %d %s %04d %02d:%02d:%02d +0900 (JST)", $week[$wday],$mday,$month[$mon],$year+1900,$hour,$min,$sec);
	return $d;
}
sub trim {
	my $val = shift;
	$val =~ s/^ *(.*?) *$/$1/;
	return $val;
}

#AuditLogの取得は
package Class_IncidentHistory;
use utf8;
use Encode;
#コンストラクタ
sub new {
	
	my $class = shift;
	my $incidenthistory = {
		#コマンドにより吐き出されるファイル
		infile => undef,
		#エラー時
		errorMsg => undef,
	};
	bless ($incidenthistory,$class);
	return $incidenthistory;
}
#インプットファイル
sub infile {
	my $incidenthistory = shift;
	if(@_) { $incidenthistory->{infile} = shift}
	return $incidenthistory->{infile};
}
sub errorMsg {
	my $incidenthistory = shift;
	if(@_) { $incidenthistory->{errorMsg} = shift}
	return $incidenthistory->{errorMsg};
}
#本日分のAuditログを取得する
sub getIncidentHistory{
	my $incidenthistory = shift;
	my $ret = "";
	my @outputlist = "";
	#一時ファイルを開く
	if(!open(IN, "<:utf8", $incidenthistory->{infile})){
		$incidenthistory->{errorMsg} =  "    File Open Error \"$incidenthistory->{infile}\" $!";
	}
	
	#一行ずつ見る
	while(my $dataline = readline IN){ 
			#push (@outputlist,encode('utf-8',$dataline)); 
			push (@outputlist,$dataline); 
	}
	
	close(IN);
		
	return @outputlist;
}
