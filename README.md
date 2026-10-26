# RMMotor

## 1. 模块作用
RoboMaster 电机驱动模块。实现 CAN 收发、反馈解析和 Motor 接口。
Manifest 描述：RoboMaster电机驱动模块

## 2. 主要函数说明
1. Decode: 解析电机反馈数据帧。
2. SendData: 打包并发送控制数据。
3. TorqueControl / CurrentControl: 力矩和电流控制路径。
4. Update / GetFeedback / Control: 标准驱动接口。
5. GetCurrentMAX / GetLSB: 模型相关换算参数。

## 3. 接入步骤
1. 添加模块并配置 model、feedback_id、can_bus_name、reverse。
2. 上电先确认反馈在线，再开放控制输出。
3. 在上层通过 Motor* 调用该驱动。

标准命令流程：
    xrobot_add_mod RMMotor --instance-id rmmotor
    xrobot_gen_main
    cube-cmake --build /home/leo/Documents/bsp-dev-c/build/debug --

## 4. 配置示例（YAML）
module: RMMotor
entry_header: Modules/RMMotor/RMMotor.hpp
constructor_args:
  - param:
      model: RMMotor::Model::MOTOR_M3508
      reverse: false
      feedback_id: 0x201
      can_bus_name: can1
template_args:
[]

## 5. 依赖与硬件
Required Hardware:
  - can

Depends:
[]

## 6. 代码入口
Modules/RMMotor/RMMotor.hpp

## LibXR 2.0 静态装配

使用 xrobot 1.0.1 的 `module` / 有序 `args`；构造函数显式注入外设与服务，实例按依赖顺序创建。参数名和顺序以头文件中的构造函数为准，固件示例见 `User/RobotConfig/`。

保留 PLDX 控制、协议、超时与离线保护。 `OnMonitor()` 由生成的监控循环直接调用。
