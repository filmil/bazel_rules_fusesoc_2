import os
print(os.environ["PYTHONPATH"])

import sys
from fusesoc.main import main
if __name__ == '__main__':
    sys.exit(main())
