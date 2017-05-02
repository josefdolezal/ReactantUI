source 'https://github.com/CocoaPods/Specs.git'
platform :ios, '9.0'
use_frameworks!
inhibit_all_warnings!

def shared
    pod 'RxSwift', '~> 3.0'
    pod 'RxCocoa', '~> 3.0'
    pod 'RxDataSources', '~> 1.0'
    pod 'RxOptional', '~> 3.0'
    pod 'SnapKit', '~> 3.0'
    pod 'Kingfisher', '~> 3.0'
    pod 'Result', '~> 3.0'
end

target 'Example' do
    shared

    pod 'Reactant', :git => 'https://github.com/Brightify/Reactant.git', :branch => 'master'
    pod 'Reactant/TableView', :git => 'https://github.com/Brightify/Reactant.git', :branch => 'master'
    pod 'ReactantUI', :path => './'
    pod 'ReactantLiveUI', :path => './', :configuration => 'Debug'
end
