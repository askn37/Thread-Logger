# NAME

Thread::Logger - マルチスレッド用のログファイル出力ヘルパー

# SYNOPSIS

    use Thread::Logger;

    my $Logger = Thread::Logger->new(
        Name => 'Foo',
        Logfile => 'Foo_%s.log',
    );
    $Logger->logs('Start');

    use threads;
    async {
        $Logger->logs('abc', undef, 'def', "hij\nklm");
        $Logger->logf('nop %d %d', 1, 2);
        $Logger->logdump({qrs => 3});
    }->join;

    $Logger->logs('End');
    $Logger->logclose;

    Ex: Foo_20160404.log;

        2016/04/04 11:49:55.090 Foo[408] Start
        2016/04/04 11:49:55.096 Foo[408:1] abc
        2016/04/04 11:49:55.096 Foo[408:1] def
        2016/04/04 11:49:55.096 Foo[408:1] hij
        2016/04/04 11:49:55.096 Foo[408:1] klm
        2016/04/04 11:49:55.096 Foo[408:1] nop 1 2
        2016/04/04 11:49:55.096 Foo[408:1] {
        2016/04/04 11:49:55.096 Foo[408:1]   'qsr' => 3
        2016/04/04 11:49:55.096 Foo[408:1] }
        2016/04/04 11:49:55.099 Foo[408] End

# DESCRIPTION

マルチスレッドでのログ出力を集めて、単一スレッドでまとめて出力できるようにする。

# CONSTRUCTOR OPTIONS

- new(key => value, ...)

    コンストラクタで指定できるオプションは以下の通り。

    - `Name`

        `name` のエイリアス。下記参照；

    - `name`

        プリントアウトに含める名前文字列を指定する。
        初期値は空文字列。

    - `Logfile`

        出力するログファイルパスを示す文字列。
        既に開かれている `IO::Handle` オブジェクトや `*GLOB` を指定することもできる。

        初期値は空、すなわち `*STDOUT` である。

        文字列指定の場合は '%s' の位置に8桁の
        ローカル日付 (Ex: '20160404') が埋め込まれる。

    - `Codepage`

        ログ出力ストリームのコードページを指定する。
        出力先がファイルの場合は `UTF-8` 固定になるため機能しない。
        そうでなければシステム既定の言語を示すコードページが使われる。
        日本語 Windows の場合の規定値は `CP932` である。

# METHODS

- $Logger->logopen

    新たなログ出力ストリームを開く。
    通常は必要に応じて内部から自動的に
    呼び出されるため意識して使用する必要はない。

- $Logger->logstdio(_\*GLOB_ ...)

    ログ出力ストリームに、指定したファイルグロブ（複数可）を結合する。
    親スレッドでのみ設定できる。

        $Logger = Thread::Logger->new()->logstdio(*STDOUT, *STDERR);

        print "STDOUT to log\n";
        warn 'STDERR to log';

    注意； この出力方法では出力行に時間/プロセス名ヘッダは付与されない。
    注意； コードページは機能しない。utfフラグ付メッセージを出力する場合は問題があるかもしれない。

- $Logger->logs(_@strings_)

    ログ出力キューに指定のテキスト（配列）を積む。
    ただし undef、空文字列、空行は 無視される。
    各要素の末尾には改行コードが付加される。

    テキストには utfフラグが付されていることが期待されている。

- $Logger->logf(_"FORMAT"_, _@args_)

    sprintf フォーマットを用いて
    成形したテキストをログ出力キューに積む。

- $Logger->logdump(...)

    `Data::Dumper->Dumper()` を用いて指定のオブジェクトをテキストに変換し、ログ出力キューに積む。

- $Logger->logflush(_WaitSeconds_)

    現在のログ出力キューをログ出力ストリームに吐き出す。
    このメソッドが呼ばれるまでログ出力キューに積まれたテキストは出力されない。
    1以上の _WaitSeconds_ を指定した場合、
    前回の出力から指定秒数が経過するまで出力は保留される。
    0または無指定の場合、出力キューは直ちに吐き出される。

- $Logger->logclose

    現在のログ出力キューを直ちに
    ログ出力ストリームへ吐き出したのちに、
    ログ出力ストリームを閉じる。

- $logname = $Logger->logname

    現在のログ出力ファイル名を返す。
    '%s' は8桁のローカル日付に置換される。

- $logdate = $Logger->logdate

    8桁のローカル日付文字列を返す。 (Ex: 20160404)

- $msec = $Logger->now

    現在の UTC時間をミリ秒 (1/1000秒) で返す。

    これは JavaScript でいう
    `jQuery.now()` や `(new Date).getTime()` と同じ結果を返す。

- $OtherObject->inherit(key => value, ...)
- $OtherObject->inherit($Logger, key => value, ...)

    任意のオブジェクトにログ機能を付与する。
    親スレッドでのみ使用できる。

    第二の書式はすでに存在する `Thread::Logger` オブジェクトを
    指定オブジェクトに結合する。
    つまり出力キューを共用する。

- $facility = $Logger->facility
- $Logger = $Logger->facility(_FACILITY_)

    Syslog出力時のファシリティ値を取得/設定する。

    初期値は `local7`。
    以下の文字列を指定できる。

    kernel user mail system security internal printer
    news uucp clock security2 FTP NTP audit alert clock2
    local0 local1 local2 local3 local4 local5 local6 local7

- $priority = $Logger->priority
- $Logger = $Logger->priority(_PRIORITY_)

    Syslog出力時のプライオリティ値を取得/設定する。

    初期値は `debug`。
    以下の文字列を指定できる。

    emergency alert crit critical err error warning
    notice info informational debug

# OBJECT PROPERTY

オブジェクトは以下のプロパティを持つ。
inherit を実行した継承オブジェクトについても同様である。

- $Logger->{Name}
- $Logger->{name}

    ログに埋め込まれる名称。
    両方を指定した場合は `Name` が優先される。
    先頭が小文字の `name` は `Win32::Service::CLI` 等が使用する。

- $Logger->{Logfile}

    new(Logfile => '...');

- $Logger->{_LOGGER}

    `Thread::Queue` オブジェクト。

- $Logger->{_LOGH}

    `IO::Handle` オブジェクト。

- $Logger->{_LOGF}

    出力中のログファイル名。

- $Logger->{_T}

    遅延出力タイミング値。

# SYSLOG PROPERTY

以下のように設定すると、ログ出力をローカルファイルではなく Syslogd サーバへ送る。

    my $Logger = Thread::Logger->new(
        Name     => 'Foo',
        Syslog   => 'rfc3194',
        PeerHost => '192.168.0.1:514',  # UDP only
        Facility => 'local7',
        Priority => 'info'
    );

Syslog プロパティに指定する値は、真に評価される値でなければならない。
原則として文字列 'rfc3194' の使用を推奨する。

この場合の Syslog プロトコルは RFC3194 に準拠し、UDP/514 で送出される。
パケットサイズが MTUサイズを超える場合、
および latin-1 ではない文字コードが含まれる場合の挙動は、不定である。

PeerHost とソケットが開けない場合は、以後はローカルファイル保存に切り替わる。
その際には最初に "colud not send syslog: <原因>" が記録されるだろう。
ふたたび Syslog 出力を試みるには $Logger オブジェクトを再生成する。

Syslog プロパティに 'multiplex' を含む文字列を与えると、
メッセージ送出に MultiPlex プロトコルが使われる。
UDP/514 の使用は同様だが、
メッセージは文字コード UTF-7 に変換して Base64 形式でパックし、
それが 1024バイトを超えるなら分割して（分割番号を付して）送出される。
このプロトコルのメッセージは、受信側が対応していなければ正しく解釈できない。

# LOG FORMAT

- **YYYY/MM/DD hh:mm:ss.sss NAME\[PID:TID\] String...**

    出力されるログファイルはこのようなフォーマットとなる。
    時間情報はローカル時刻である。

    - _YYYY_

        年 (1900-)

    - _MM_

        月 (01-12)

    - _DD_

        日 (01-31)

    - _hh_

        時 (00-23)

    - _mm_

        分 (00-59)

    - _ss.sss_

        秒.マイクロ秒 (00.000-59.999)

    - _NAME_

        名称；
        `new(name=>'String')` で設定する。

    - _PID_

        プロセスID ( $$ )

    - _TID_

        スレッドID； ( threads::thread->tid )
        親スレッドでは空になる。

# INHERITANCE EXAMPLE

ユーザモジュールに Thread::Logger を組み込むには次のようにする。

    package MyModule;
    use Thread::Logger ':import'

    sub new {
        my $class = shift;
        $object = bless {}, ref $class || $class || __PACKAGE__;

        $object->Thread::Logger::inherit(
            # 規定値
            Name => 'somename',
            Logfile => '/path/to/somename_%s.log',
            # 上書きするパラメータ
            @_
        );
        return $object;
    }

    package main;
    use MyModule;

    my $object = MyModule->new(
        Name => 'anyname',
        Logfile => '/path/to/anyname_%s.log',
    );

    $object->logs('log text');
    $object->logflush;

# AUTHOR

朝日薫 / askn
Twitter: [@askn37](https://twitter.com/askn37)
GitHub: https://github.com/askn37

# COPYRIGHT AND LICENSE

Copyright 2016 朝日薫 / askn

This library is free software; you may redistribute
it and/or modify it under the same terms as Perl itself.

# SEE ALSO

[therads](https://metacpan.org/pod/therads),
[Thread::Queue](https://metacpan.org/pod/Thread::Queue),
[Win32::Service::CLI](https://metacpan.org/pod/Win32::Service::CLI),
[Win32::Service::Syslogd](https://metacpan.org/pod/Win32::Service::Syslogd)
