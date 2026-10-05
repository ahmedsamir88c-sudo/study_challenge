from django.db import migrations


LECTURE_CONTENT = """Computer Organization and Architecture: Lecture 1 Study Notes

Purpose of the subject
Computer organization and architecture explain how a computer is designed, how its parts cooperate, and how these choices affect program behavior and performance. This knowledge helps programmers reason about system software, optimize programs, compare computer performance, and understand trade-offs among speed, capacity, and cost.

Architecture and organization
Computer architecture describes properties visible to software, including the instruction set, data representations, addressing methods, and input/output behavior. Computer organization describes how hardware implements those properties, including circuits, control signals, memory technology, and connections between components. A computer family can preserve one architecture while changing its organization to offer different performance or cost.

Structure and function
Structure is the way components are connected. Function is the work each component performs within that structure. A computer performs four broad functions: processing data, storing data, moving data between components or the outside world, and controlling those activities.

Main components
The main structural components are the central processing unit (CPU), main memory, input/output (I/O), and a system interconnection that lets them communicate. Within the CPU, the control unit coordinates instruction execution, the arithmetic and logic unit (ALU) performs calculations and logical operations, registers hold values needed immediately, and internal connections carry data and control signals.

Stored-program and von Neumann model
A stored-program computer keeps instructions in memory so the CPU can retrieve and execute them. A typical system includes a CPU, main memory, and I/O. The control unit uses the program counter to locate the next instruction, fetches it, decodes it, obtains required operands, and directs execution. Results are placed in registers or memory. This repeating fetch-decode-execute process enables a general-purpose computer to run different programs without rewiring its hardware for each task.

When instructions and data share a constrained path between the CPU and memory, transfer capacity can limit overall performance. This limitation is known as the von Neumann bottleneck. Caches, specialized buses, and parallel processing are examples of developments used to improve performance, although each introduces design trade-offs.

Levels of abstraction
Computer systems can be understood as layers. Users interact with applications; programs are expressed in high-level languages, translated through system software and assembly, and ultimately represented as machine instructions. Control logic and digital circuits carry out those instructions. Each layer offers a simpler view of lower-level details, allowing complex systems to be designed and studied one level at a time.

Historical perspective
Computing developed from mechanical calculators to electronic machines using vacuum tubes, then transistors, integrated circuits, and very large-scale integrated circuits. Increasing integration enabled microprocessors and personal computers. Moore's observation described a historical trend in transistor density; it should be treated as an observation about technological growth, not a guarantee that growth continues indefinitely. Later performance improvements also came from caches, pipelines, multicore processors, and parallel systems.

Key ideas to review
Be able to distinguish architecture from organization; identify the CPU, memory, I/O, and system interconnection; explain the roles of the control unit, ALU, and registers; describe the fetch-decode-execute cycle; explain stored-program operation and the von Neumann bottleneck; and name the four broad computer functions."""


def seed_lecture(apps, schema_editor):
    LectureContent = apps.get_model("users", "LectureContent")
    LectureContent.objects.get_or_create(
        subject="Computer Architecture",
        lecture_number=1,
        defaults={"content": LECTURE_CONTENT},
    )


class Migration(migrations.Migration):
    dependencies = [("users", "0006_lecturecontent")]

    operations = [
        migrations.RunPython(seed_lecture, migrations.RunPython.noop),
    ]