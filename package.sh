#!/bin/bash
broker_git_address="https://github.com/WeBankFinTech/WeEvent.git"
broker_tag=""
broker_project_name=""
governance_git_address="https://github.com/WeBankFinTech/WeEvent-governance.git"
governance_tag=""
governance_project_name=""
nginx_tag=""
version=""
top_path=`pwd`

function usage(){
    echo "Usage:"
    echo "     package weevent: ./package.sh --version 0.9.0"
    echo "     package broker module: ./package.sh --broker tag --version 0.9.0"
    echo "     package nginx module: ./package.sh --nginx tag --version 0.9.0"
    echo "     package governance module: ./package.sh --governance tag --version 0.9.0"
    exit 1
}

param_count=$#

if [ $param_count -ne 2 ] && [ $param_count -ne 4 ]; then
    usage
fi

while [ $# -ge 2 ] ; do
    case "$1" in
    --broker) para="$1 = $2;";broker_tag=$2;shift 2;;
    --nginx) para="$1 = $2;";nginx_tag=$2;shift 2;;
    --governance) para="$1 = $2;";governance_tag=$2;shift 2;;
    --version) para="$1 = $2;";version="$2";shift 2;;
    *) echo "unknown parameter $1." ; exit 1 ; break;;
    esac
done

weevent_out_path=$top_path/weevent-$version
module_out_path=$top_path/modules

if [ -z "$broker_tag" ] && [ -z "$governance_tag" ] && [ -z "$nginx_tag" ];then
    echo "param broker_git_address:"$broker_git_address
    echo "param governance_git_address:"$governance_git_address
else
    if [ -n "$broker_tag" ];then
        echo "param broker_git_address:"$broker_git_address
    fi
    if [ -n "$governance_tag" ];then
        echo "param governance_git_address:"$governance_git_address
    fi
fi

if [ -n "$version" ];then
    echo "param version:"$version
else
    echo "package version is null"
    exit 1
fi	


function copy_file(){ 
    cp ./check-service.sh $weevent_out_path
    cp ./config.ini $weevent_out_path
    cp ./install-all.sh $weevent_out_path
    cp ./README.md $weevent_out_path
    cp ./start-all.sh $weevent_out_path
    cp ./stop-all.sh $weevent_out_path
    cp ./uninstall-all.sh $weevent_out_path
    cp -r ./third-packages $weevent_out_path
	
    mkdir -p $weevent_out_path/modules/broker
    cp ./modules/broker/install-broker.sh $weevent_out_path/modules/broker
    mkdir -p $weevent_out_path/modules/governance
    cp ./modules/governance/install-governance.sh $weevent_out_path/modules/governance
    mkdir -p $weevent_out_path/modules/nginx
    cp ./modules/nginx/install-nginx.sh $weevent_out_path/modules/nginx  
    cp ./modules/nginx/nginx.sh $weevent_out_path/modules/nginx 
    cp -r ./modules/nginx/conf $weevent_out_path/modules/nginx 
}

# clone broker from git, build
function broker_clone_build(){
    cd $out_path/broker
    if [ -d $out_path/broker/temp ];then
        rm -rf $out_path/broker/temp
    fi
	
    mkdir -p temp
    cd temp
    echo "clone broker from git start"
    # clone
    git clone $broker_git_address
    execute_result "clone broker from git"
    yellow_echo "clone broker from git success"
	
    if [ $(echo `ls -l |grep "^d"|wc -l`) -ne 1 ];then
        exit 1
    fi
	
    broker_project_name=$(ls -l | awk '/^d/{print $NF}')
    if [ -z "$broker_project_name" ];then
        echo "clone broker fail"
        exit 1
    fi 
	
    if [ -e $out_path/broker/temp/$broker_project_name/build.gradle ]; then 
        sed -i "/^version/cversion = \"$version\""  $out_path/broker/temp/$broker_project_name/build.gradle
        execute_result "config broker version"        
    fi
	
    cd $broker_project_name	 
    echo "build broker start"
    # build
    gradle clean build -x test;
    execute_result "broker build"
	
    if [ -e $out_path/broker/temp/$broker_project_name/conf/application-dev.properties ]; then 
        rm $out_path/broker/temp/$broker_project_name/conf/application-dev.properties
    fi
    yellow_echo "build broker success"       
}

# clone governance from git, build
function governance_clone_build(){
    cd $out_path/governance/
    if [ -d $out_path/governance/temp ];then
        rm -rf $out_path/governance/temp
    fi
	
    mkdir -p temp
    cd  temp 
    echo "clone governance from git start "
    # clone
    git clone $governance_git_address
    execute_result "clone governance from git"
    yellow_echo "clone governance from git success  "
	
    if [ $(echo `ls -l |grep "^d"|wc -l`) -ne 1 ];then
        exit 1
    fi
	
    governance_project_name=$(ls -l | awk '/^d/{print $NF}')
    if [ -z "$governance_project_name" ];then
        echo "clone governance fail"
        exit 1
    fi
	
    if [ -e $out_path/governance/temp/$governance_project_name/build.gradle ]; then
        sed -i "/^version/cversion = \"$version\"" $out_path/governance/temp/$governance_project_name/build.gradle
        execute_result "config governance version"                       
    fi
	
    cd $governance_project_name
    echo "build governance start "
    # build
    gradle clean build -x test
    execute_result "governance build" 

    if [ -e $out_path/governance/temp/$governance_project_name/dist/conf/application-dev.yml ]; then
        rm $out_path/governance/temp/$governance_project_name/dist/conf/application-dev.yml                       
    fi	
    yellow_echo "build governance success "	    
}

function execute_result(){
    if [ $? -ne 0 ];then
        echo "$1 fail"
        exit 1
    fi	 	 
}

# chmod $ dos2unix
function set_permission(){
    cd $1	
    find $1 -name "*.sh" -exec chmod +x {} \;
    find $1 -name "*.sh" -exec dos2unix {} \;
    find $1 -name "*.ini" -exec dos2unix {} \;
    find $1 -name "*.properties" -exec dos2unix {} \;
    cd ..
}

# switch to prod,remove dev properties
function switch_to_prod(){
    if [ -z "$broker_tag" ] && [ -z "$governance_tag" ];then
        if [ -e $out_path/broker/conf/application.properties ]; then	    
            sed -i 's/dev/prod/' $out_path/broker/conf/application.properties
        fi

        if [ -e $out_path/governance/conf/application.yml ]; then	    
            sed -i 's/dev/prod/' $out_path/governance/conf/application.yml		
        fi
	
        if [ -e $out_path/broker/conf/application-dev.properties ]; then	
            rm $out_path/broker/conf/application-dev.properties
        fi

        if [ -e $out_path/governance/conf/application-dev.yml ]; then	    
            rm $out_path/governance/conf/application-dev.yml	
        fi
    else
        if [ -e $out_path/broker/weevent-broker-$version/conf/application.properties ]; then	    
            sed -i 's/dev/prod/' $out_path/broker/weevent-broker-$version/conf/application.properties
        fi

        if [ -e $out_path/governance/weevent-governance-$version/conf/application.yml ]; then	    
            sed -i 's/dev/prod/' $out_path/governance/weevent-governance-$version/conf/application.yml		
        fi
	
        if [ -e $out_path/broker/weevent-broker-$version/conf/application-dev.properties ]; then	
            rm $out_path/broker/weevent-broker-$version/conf/application-dev.properties
        fi

        if [ -e $out_path/governance/weevent-governance-$version/conf/application-dev.yml ]; then	    
            rm $out_path/governance/weevent-governance-$version/conf/application-dev.yml	
        fi
    fi
}

function confirm(){
    # confirm
    if [ -d $1 ]; then
        read -p "$out_path already exist, continue? [Y/N]" cmd_input
        if [ "Y" != "$cmd_input" ]; then
            echo "input $cmd_input, install skipped"
            exit 1
        fi
    fi
}

function yellow_echo () {
    local what=$*
    if true;then
        echo -e "\e[1;33m${what} \e[0m"
    fi
}

# package weevent-$version
function package_weevent(){
    local out_path=""
    confirm $weevent_out_path 
    mkdir -p weevent-$version
    execute_result "mkdir weevent-$version"
    copy_file
    out_path=$weevent_out_path/modules
        
    broker_clone_build $out_path
    cp -r $out_path/broker/temp/$broker_project_name/dist/* $out_path/broker
    cd $out_path/broker
    rm -rf temp
    echo "copy broker dist over "
        
    governance_clone_build $out_path
    cp -r $out_path/governance/temp/$governance_project_name/dist/* $out_path/governance
    cd $out_path/governance
    rm -rf temp
    echo "copy governance dist over " 
                 
    switch_to_prod $out_path            
    set_permission $weevent_out_path
        
    echo "tar weevent-$version start "
    tar -czvf weevent-$version.tar.gz weevent-$version
    rm -rf weevent-$version
    execute_result "remove folder weevent-$version"
}

# package weevent-broker-$version
function package_weevent_broker(){
    local out_path=""
    out_path=$module_out_path 
    confirm $out_path/broker/weevent-broker-$version 
    cd $out_path/broker           
    mkdir -p weevent-broker-$version
    execute_result "mkdir weevent-broker-$version"
           
    broker_clone_build $out_path 
    
    cp -r $out_path/broker/temp/$broker_project_name/dist/* $out_path/broker/weevent-broker-$version
    cd $out_path/broker
    rm -rf temp
    echo "copy weevent-broker dist over " 
        
    switch_to_prod $out_path    
    set_permission $out_path/broker/weevent-broker-$version
    
    echo "tar weevent-broker-$version start "
    tar -czvf weevent-broker-$version.tar.gz weevent-broker-$version
    rm -rf weevent-broker-$version
    execute_result "remove folder weevent-broker-$version"
}

# package weevent-governance-$version
function package_weevent_governance(){
    local out_path=""
    out_path=$module_out_path       
    confirm $out_path/governance/weevent-governance-$version  
    cd $out_path/governance      
    mkdir -p weevent-governance-$version
    execute_result "mkdir weevent-governance-$version"
    
    governance_clone_build $out_path
    
    cp -r $out_path/governance/temp/$governance_project_name/dist/* $out_path/governance/weevent-governance-$version
    cd $out_path/governance
    rm -rf temp
    echo "copy weevent-governance dist over  " 
          
    switch_to_prod $out_path   
    set_permission $out_path/governance/weevent-governance-$version
    
    echo "tar weevent-governance-$version start "
    tar -czvf weevent-governance-$version.tar.gz weevent-governance-$version
    rm -rf weevent-governance-$version
    execute_result "remove folder weevent-governance-$version"
}

# package weevent-nginx-$version
function package_weevent_nginx(){
    local out_path=""
    out_path=$module_out_path       
    confirm $out_path/nginx/weevent-nginx-$version  
    cd $out_path/nginx      
    mkdir -p weevent-nginx-$version
    execute_result "mkdir weevent-nginx-$version"
     
    cp -r ./conf/ ./weevent-nginx-$version
    cp ./nginx.sh ./weevent-nginx-$version
    cp ./build-nginx.sh ./weevent-nginx-$version
    mkdir -p weevent-nginx-$version/third-packages
    cp $top_path/third-packages/nginx-1.14.2.tar.gz ./weevent-nginx-$version/third-packages
    cp $top_path/third-packages/pcre-8.20.tar.gz ./weevent-nginx-$version/third-packages  
           
    set_permission $out_path/nginx/weevent-nginx-$version
    
    echo "tar weevent-nginx-$version start "
    tar -czvf weevent-nginx-$version.tar.gz weevent-nginx-$version
    rm -rf weevent-nginx-$version
    execute_result "remove folder weevent-nginx-$version"
}

function main(){ 
           
    # package
    if [ -z "$broker_tag" ] && [ -z "$governance_tag" ] && [ -z "$nginx_tag" ];then
		package_weevent        
    else
        if [ -n "$broker_tag" ];then
            package_weevent_broker
        fi
		
        if [ -n "$governance_tag" ];then
            package_weevent_governance
        fi
		
        if [ -n "$nginx_tag" ];then
            package_weevent_nginx
        fi   
    fi  
    
    yellow_echo "package success "
}

main